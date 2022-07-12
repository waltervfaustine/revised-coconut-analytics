_ = require 'underscore'
$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $
moment = require 'moment'
Dhis2 = require './Dhis2'

Individual = require './Individual'
TertiaryIndex = require './TertiaryIndex'
class Specimen
  
  constructor: (options) ->
    @specimenID = options?.specimenIDs
    @loadData(options.results) if options?.results
  loadData: (resultDocs) ->
    _.each resultDocs, (resultDoc) => 
      if(resultDoc)
        @specimenID ?= resultDoc?["id"]
        @District ?= resultDoc?["district"]
        @district ?= resultDoc?["district"]
        @Shehia ?= resultDoc?["shehia"]
        @shehia ?= resultDoc?["shehia"]
        @methodOfCollection ?= resultDoc?["method-of-collection"]
        @morphologicalIdentification ?= (resultDoc["morphological-identification-of-mosquito"])?.replace('\n','')
     
  facility: ->
    @facilityUnit()?.name or "UNKNOWN"
    #@["Case Notification"]?.FacilityName.toUpperCase() or @["USSD Notification"]?.hf.toUpperCase() or @["Facility"]?.FacilityName or "UNKNOWN"

  facilityType: =>
    facilityUnit = @facilityUnit()
    unless facilityUnit?
      console.warn "Unknown facility name for: #{@specimenID}. Returning UNKNOWN for facilityType."
      return "UNKNOWN"
    GeoHierarchy.facilityTypeForFacilityUnit(@facilityUnit())

  facilityDhis2OrganisationUnitId: =>
    GeoHierarchy.findFirst(@facility(), "FACILITY")?.id

  isShehiaValid: =>
    if @validShehia() then true else false

  validShehia: =>
    @shehiaUnit()?.name
    # Try and find a shehia is in our database
    if @Shehia and GeoHierarchy.validShehia(@Shehia )
      return @Shehia

  shehiaUnit: (shehiaName, districtName) =>
    if shehiaName? and GeoHierarchy.validShehia(shehiaName)
      # Can pass in a shehiaName - useful for positive Individuals with different focal area
    else
      shehiaName = null
      # Priority order to find the best facilityName
      for name in [@Household?.Shehia, @Facility?.Shehia,  @["Case Notification"]?.Shehia, @["USSD Notification"]?.shehia]
        continue unless name?
        name = name.trim()
        if GeoHierarchy.validShehia(name)
          shehiaName = name
          break

    unless shehiaName?
      # If we have no valid shehia name, then try and use facility
      return @facilityUnit()?.ancestorAtLevel("SHEHIA")
    else
      shehiaUnits = GeoHierarchy.find(shehiaName,"SHEHIA")

      if shehiaUnits.length is 1
        return shehiaUnits[0]
      else if shehiaUnits.length > 1
        # At this point we have a shehia name, but it is not unique, so we can use any data to select the correct one
        # Shehia names are not unique across Zanzibar, but they are unique per island
        # We also have region which is a level between district and island.
        # Strategy: get another sub-island location from the data, then limit the
        # list of shehias to that same island
        # * "District" that was passed in (used for focal areas)
        #     Is Shehia in district?
        # * "District" from Household
        #     Is Shehia in district?
        # * "District for Shehia" from Case Notification
        #     Is Shehia in district?
        # * Facility District
        #     Is Shehia in District
        # * Facility Name
        #     Is Shehia parent of facility
        # * If REGION for FACILTY unit matches one of the shehia's region
        # * If ISLAND for FACILTY unit matches one of the shehia's region
        for district in [districtName, @Household?["District"], @["Case Notification"]?["District for Shehia"], @["Case Notification"]?["District for Facility"], @["USSD Notification"]?.facility_district]
          continue unless district?
          district = district.trim()
          districtUnit = GeoHierarchy.findOneMatchOrUndefined(district, "DISTRICT")
          if districtUnit?
            for shehiaUnit in shehiaUnits
              if shehiaUnit.ancestorAtLevel("DISTRICT") is districtUnit
                return shehiaUnit
            # CHECK THE REGION LEVEL
            for shehiaUnit in shehiaUnits
              if shehiaUnit.ancestorAtLevel("REGION") is districtUnit.ancestorAtLevel("REGION")
                return shehiaUnit
            # CHECK THE ISLAND LEVEL
            for shehiaUnit in shehiaUnits
              if shehiaUnit.ancestorAtLevel("ISLAND") is districtUnit.ancestorAtLevel("ISLAND")
                return shehiaUnit

        # In case we couldn't find a facility district above, try and use the facility unit which comes from the name
        facilityUnit = @facilityUnit()
        if facilityUnit?
          facilityUnitShehia = facilityUnit.ancestorAtLevel("SHEHIA")
          for shehiaUnit in shehiaUnits
            if shehiaUnit is facilityUnitShehia
              return shehiaUnit

          for level in ["DISTRICT", "REGION", "ISLAND"]
            facilityUnitAtLevel = facilityUnit.ancestorAtLevel(level)
            for shehiaUnit in shehiaUnits
              shehiaUnitAtLevel = shehiaUnit.ancestorAtLevel(level)
              #console.log "shehiaUnitAtLevel: #{shehiaUnitAtLevel.id}: #{shehiaUnitAtLevel.name}"
              #console.log "facilityUnitAtLevel: #{facilityUnitAtLevel.id}: #{facilityUnitAtLevel.name}"
              if shehiaUnitAtLevel is facilityUnitAtLevel
                return shehiaUnit

  villageFromGPS: =>
    longitude = @householdLocationLongitude()
    latitude = @householdLocationLatitude()
    if longitude? and latitude?
      GeoHierarchy.villagePropertyFromGPS(longitude, latitude)


  shehiaUnitFromGPS: =>
    longitude = @householdLocationLongitude()
    latitude = @householdLocationLatitude()
    if longitude? and latitude?
      GeoHierarchy.findByGPS(longitude, latitude, "SHEHIA")

  shehiaFromGPS: =>
    @shehiaUnitFromGPS()?.name

  facilityUnit: =>
    facilityName = null
    # Priority order to find the best facilityName
    for name in [@Facility?.FacilityName, @["Case Notification"]?.FacilityName, @["USSD Notification"]?["hf"]]
      continue unless name?
      name = name.trim()
      if GeoHierarchy.validFacility(name)
        facilityName = name
        break

    if facilityName
      facilityUnits = GeoHierarchy.find(facilityName, "HEALTH FACILITIES")
      if facilityUnits.length is 1
        return facilityUnits[0]
      else if facilityUnits.length is 0
        return null
      else if facilityUnits.length > 1

        facilityDistrictName = null
        for name in [@Facility?.DistrictForFacility, @["Case Notification"]?.DistrictForFacility, @["USSD Notification"]?["facility_district"]]
          if name? and GeoHierarchy.validDistrict(name)
            facilityDistrictName = name
            break

        if facilityDistrictName?
          facilityDistrictUnits = GeoHierarchy.find(facilityDistrictName, "DISTRICT")
          for facilityUnit in facilityUnits
            for facilityDistrictUnit in facilityDistrictUnits
              if facilityUnit.ancestorAtLevel("DISTRICT") is facilityDistrictUnit
                return facilityUnit


  householdShehiaUnit: =>
    @shehiaUnit()

  householdShehia: =>
    @householdShehiaUnit()?.name

  shehia: ->
    returnVal = @validShehia()
    return returnVal if returnVal?


    # If no valid shehia is found, then return whatever was entered (or null)
    returnVal = @.Household?.Shehia || @.Facility?.Shehia || @["Case Notification"]?.shehia || @["USSD Notification"]?.shehia

    if @hasCompleteFacility()
      if @complete()
        console.warn "Case was followed up to household, but shehia name: #{returnVal} is not a valid shehia. #{@MalariaCaseID()}."
      else
        console.warn "Case was followed up to facility, but shehia name: #{returnVal} is not a valid shehia: #{@MalariaCaseID()}."

    return returnVal

  village: ->
    @["Facility"]?.Village

  facilityDistrict: ->
    facilityDistrict = @["USSD Notification"]?.facility_district
    unless facilityDistrict and GeoHierarchy.validDistrict(facilityDistrict)
      facilityDistrict = @facilityUnit()?.ancestorAtLevel("DISTRICT").name
    unless facilityDistrict
      #if @["USSD Notification"]?.facility_district is "WEST" and _(GeoHierarchy.find(@shehia(), "SHEHIA").map( (u) => u.ancestors()[0].name )).include "MAGHARIBI A" # MEEDS doesn't have WEST split
      #
      #
      # WEST got split, but DHIS2 uses A & B, so use shehia to figure out the right one
      if @["USSD Notification"]?.facility_district is "WEST"
        if shehia = @validShehia()
          for shehia in GeoHierarchy.find(shehia, "SHEHIA")
            if shehia.ancestorAtLevel("DISTRICT").name.match(/MAGHARIBI/)
              return shehia.ancestorAtLevel("DISTRICT").name
        else
          return "MAGHARIBI A"
        #Check the shehia to see if it is either MAGHARIBI A or MAGHARIBI B

      console.warn "Could not find a district for USSD notification: #{JSON.stringify @["USSD Notification"]}"
      return "UNKNOWN"
    GeoHierarchy.swahiliDistrictName(facilityDistrict)

  districtUnit: ->
    districtUnit = @shehiaUnit()?.ancestorAtLevel("DISTRICT") or @facilityUnit()?.ancestorAtLevel("DISTRICT")
    return districtUnit if districtUnit?

    for name in [@Facility?.DistrictForFacility, @["Case Notification"]?.DistrictForFacility, @["USSD Notification"]?["facility_district"]]
      if name? and GeoHierarchy.validDistrict(name)
        return GeoHierarchy.findOneMatchOrUndefined(name, "DISTRICT")

  district: =>
    @districtUnit()?.name or "UNKNOWN"

  islandUnit: =>
    @districtUnit()?.ancestorAtLevel("ISLANDS")

  island: =>
    @islandUnit()?.name or "UNKNOWN"

  highRiskShehia: (date) =>
    date = moment().startOf('year').format("YYYY-MM") unless date
    if Coconut.shehias_high_risk?[date]?
      _(Coconut.shehias_high_risk[date]).contains @shehia()
    else
      false

  locationBy: (geographicLevel) =>
    return @validShehia() if geographicLevel.match(/shehia/i)
    district = @District
    if district?
      return district if geographicLevel.match(/district/i)
      GeoHierarchy.getAncestorAtLevel(district, "DISTRICT", geographicLevel)
    else
      console.warn "No district for case: #{@specimenID}"

  # namesOfAdministrativeLevels
  # Nation, Island, Region, District, Shehia, Facility
  # Example:
  #"ZANZIBAR","PEMBA","KUSINI PEMBA","MKOANI","WAMBAA","MWANAMASHUNGI
  namesOfAdministrativeLevels: () =>
    district = @District
    if district
      districtAncestors = _(GeoHierarchy.findFirst(district, "DISTRICT")?.ancestors()).pluck "name"
      result = districtAncestors.reverse().concat(district).concat(@shehia()).concat(@facility())
      result.join(",")

  module.exports = Specimen
