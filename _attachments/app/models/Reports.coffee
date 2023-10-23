_ = require 'underscore'
moment = require 'moment'

Case = require './Case'
Specimen = require './Specimen'

class Reports

  positiveCaseLocations: (options) ->

    # Query not in database - probably should be handled by better geo-optimized code
    Coconut.database.query "positiveCaseLocations",
      startkey: moment(options.endDate).endOf("day").format(Coconut.config.get "date_format")
      endkey: options.startDate
      descending: true
    .catch (error) ->
      options?.error()
    .then (result) =>
      locations = []
      for currentLocation,currentLocationIndex in result.rows
        currentLocation = currentLocation.value
        locations[currentLocation] =
          100:[]
          1000:[]
          5000:[]
          10000:[]

        for loc, locIndex in result.rows
          continue if locIndex is currentLocationIndex
          loc = loc.value
          distanceInMeters = (new LatLon(currentLocation[0],currentLocation[1])).distanceTo(new LatLon(loc[0],loc[1])) * 1000
          if distanceInMeters<100
            locations[currentLocation][100].push loc
          else if distanceInMeters<1000
            locations[currentLocation][1000].push loc
          else if distanceInMeters<5000
            locations[currentLocation][5000].push loc
          else if distanceInMeters<10000
            locations[currentLocation][10000].push loc

      options.success(locations)

  positiveCaseClusters: (options) ->
    @positiveCaseLocations
      success: (positiveCases) ->
        for positiveCase, cluster of positiveCases
          if (cluster[100].length) > 4
            console.log "#{cluster[100].length} cases within 100 meters of one another"

  @getCases = (options) =>
    Coconut.reportingDatabase.query "allCasesAcceptedByDMSO",
      # Note that these seem reversed due to descending order
      startkey: moment(options.endDate).endOf("day").format(Coconut.config.dateFormat)
      endkey: options.startDate
      descending: true
      include_docs: false
    .catch (error) -> console.error error
    .then (result) ->
      caseIDs = _.unique(_.pluck result.rows, "value")

      console.log "JSON::: ", JSON.stringify(caseIDs)

      Coconut.database.query "getAcceptedCasesByParams",
        keys: caseIDs
        include_docs: true
      .catch (error) -> console.error error
      .then (result) =>    
        reportsInstance = new Reports()
        filteredResults = reportsInstance.filterDocumentsByKeys(caseIDs, result.rows, 'key')

        groupedResults = _.chain(filteredResults)
          .groupBy (row) =>
            row.key
          .map (resultsByCaseID) =>
            malariaCase = new Case
              results: _.pluck resultsByCaseID, "doc"
            if not options.mostSpecificLocation?
              return malariaCase
            else if  options.mostSpecificLocation.name is "ALL" or malariaCase.withinLocation(options.mostSpecificLocation)
              return malariaCase
          .compact()
          .value()
        options.success? groupedResults or Promise.resolve(groupedResults)

  @getSpecimens = (options) =>
    Coconut.entomologyDatabase.query "specimensByDate",
      # Note that these seem reversed due to descending order
      startkey: moment(options.endDate).endOf("day").format(Coconut.config.dateFormat)
      endkey: options.startDate
      descending: true
      include_docs: true
    .catch (error) -> console.error error
    .then (result) ->
      specimenData = _.map(result.rows, (res)->
        { ...res.value, id:res.doc._id })
      specimenIDs = _.unique(specimenData)
      groupedResults = _.chain(specimenIDs)
        .groupBy (row) =>
          row['id']
        .map (specimen) =>
          specimen = new Specimen
            results: specimen
          if not options.mostSpecificLocation?
            return specimen
          else if  options.mostSpecificLocation.name is "ALL" or specimen.withinLocation(options.mostSpecificLocation)
            return specimen
        .compact()
        .value()
      options.success? groupedResults or Promise.resolve(groupedResults)

  # legacy support - use the static one instead
  getCases: (options) =>
    Reports.getCases(options)

  ###
  Filter documents based on a list of keys.

  @param {Array} keys - The list of keys to filter documents by.
  @param {Array} allDocuments - An array containing all the documents from the database.
  @param {String} prop - The property name in the documents to compare with the keys.
  @return {Array} - An array containing filtered documents whose specified property values match the provided keys.
  ###
  filterDocumentsByKeys: (keys, allDocuments, prop) ->
      # Filter documents based on keys using the filter function
      filteredDocs = allDocuments.filter((doc) -> keys.includes(doc[prop].trim()))
      filteredDocs

  ###
  This method fetches notified cases from the shokishoki database based on the specified options.

  @param {Object} options - The query options containing start and end dates.
  @return {Promise} - A Promise that resolves with the query result or rejects with an error.
  ###
  getShokishokiCases: (options) ->
      console.log "Fetching notified cases from the shokishoki database..."
      
      # Perform a query on the shokishoki database
      queryPromise = Coconut.shokishokiDatabase.query "notifiedCasesAtFacilityLevel",
          startkey: moment(options.endDate).endOf("day").format(Coconut.config.dateFormat)
          endkey: options.startDate
          descending: true
          include_docs: true

      # Handle successful query result
      queryPromise = queryPromise.then (result) =>
          console.log "Notified cases fetched successfully."
          Promise.resolve(result)

      # Handle query errors
      queryPromise = queryPromise.catch (error) =>
          console.error "Error fetching notified cases:", error
          Promise.reject(error)

      # Return the Promise
      queryPromise


  ###
  This method fetches notified cases within 24 hours from the notification zanzibar database based on the specified options.

  @param {Object} options - The query options containing start and end dates.
  @return {Promise} - A Promise that resolves with the query result or rejects with an error.
  @throws {Error} - If there is an error fetching the notified cases.
  ###
  getCasesNotifiedWith24Hrs: (options) ->
      context = "Fetching notified cases within 24 hours from the notification zanzibar database..."
      console.log context
      
      # Perform a query on the notification zanzibar database
      queryPromise = Coconut.notificationDatabase.query "casesNotifiedWith24HRS",
          startkey: moment(options.endDate).endOf("day").format(Coconut.config.dateFormat)
          endkey: options.startDate
          descending: true
          include_docs: true

      # Handle successful query result
      queryPromise = queryPromise.then (result) =>
          console.log "Notified cases fetched successfully."
          Promise.resolve(result)

      # Handle query errors
      queryPromise = queryPromise.catch (error) =>
          console.error "Error fetching notified cases:", error
          throw new Error("Error fetching notified cases: #{error}")

      # Return the Promise
      queryPromise



  ###
  This function extracts the "facility-district" property from the provided payload.

  @param {Object} payload - The payload object from which the "facility-district" property will be extracted.
  @return {string|null} - The extracted "facility-district" property or null if not found.
  ###
  extractFacilityDistrict = (payload) ->
      # Check if the payload and doc property exist and if "facility-district" property is present
      if payload?.doc? && payload.doc["facility-district"]?
          # Return the extracted "facility-district" property
          return payload.doc["facility-district"]
      else
          # Return null if "facility-district" property is not found
          return 'UNKNOWN'


  @casesAggregatedForAnalysis = (options) =>
    new Promise (resolve, reject) =>

      data = {}

      options.aggregationLevel ||= "DISTRICT"

      # Hack required because we have multiple success callbacks
      options.finished = options.success

      # Instantiate your class
      reportsInstance = new Reports()

      # Call the method with the appropriate options
      reportsInstance.getShokishokiCases(options)
        .then (result) =>
          if result?.rows?.length > 0
            # START NOW 
            Reports.getCases _.extend options,
              success: (cases) =>
                IRSThresholdInMonths = 6

                data.followups = {}
                data.passiveCases = {}
                data.ages = {}
                data.gender = {}
                data.netsAndIRS = {}
                data.travel = {}
                data.individualClassification = {}
                data.totalPositiveCases = {}

                # Setup hashes for each table
                aggregationNames = GeoHierarchy.all options.aggregationLevel
                aggregationNames.push("UNKNOWN")
                aggregationNames.push("ALL")

                _.each aggregationNames, (aggregationName) ->
                  data.followups[aggregationName] =
                    allShoki: []
                    allCases: []
                    caseNotifiedWith24HRS: []
                    casesWithCompleteFacilityVisit: []
                    casesInvestigatedDueToAnotherCaseInvestigation: []
                    casesWithoutCompleteFacilityVisit: []
                    casesWithCompleteHouseholdVisit: []
                    casesWithoutCompleteHouseholdVisit: []
                    missingUssdNotification: []
                    missingCaseNotification: []
                    noFacilityFollowupWithin24Hours: []
                    noHouseholdFollowupWithin48Hours: []
                    multipleNotified: []
                    falsePositive: []
                    notVerified: []
                    casesForInvestigation: []
                    casesForFullInvestigation: []
                    lostToFollowUp: []
                    houseWithMoreThanOnePositiveCase: []
                  data.passiveCases[aggregationName] =
                    indexCases: []
                    indexCaseHouseholdMembers: []
                    positiveIndividualsAtIndexHousehold: []
                    neighborHouseholds: []
                    neighborHouseholdMembers: []
                    positiveIndividualsAtNeighborHouseholds: []
                  data.ages[aggregationName] =
                    underFive: []
                    fiveToFifteen: []
                    fifteenToTwentyFive: []
                    overTwentyFive: []
                    unknown: []
                  data.gender[aggregationName] =
                    male: []
                    female: []
                    unknown: []
                  data.netsAndIRS[aggregationName] =
                    sleptUnderNet: []
                    recentIRS: []
                  data.travel[aggregationName] =
                    "No":[]
                    "Yes":[] # This needs to be here for old cases
                    "Yes within Zanzibar":[]
                    "Yes outside Zanzibar":[]
                    "Yes within and outside Zanzibar":[]
                    "Any travel":[]
                    "Not Applicable":[]
                  data.totalPositiveCases[aggregationName] = []

                  data.individualClassification[aggregationName] =
                    withTravelHistory: [],
                    imported: []
                    indigenous: []
                    introduced: []
                    induced: []
                    relapsing: []

                _.each cases, (malariaCase) ->
                  caseLocation = malariaCase.locationBy(options.aggregationLevel) || "UNKNOWN"

                  unless data.followups[caseLocation]
                    console.log "Case location #{caseLocation} not found"
                    # Search for it since it may need an alias/translation
                    caseLocation = GeoHierarchy.find(caseLocation,options.aggregationLevel)?[0]?.name or "UNKNOWN"
                    console.log "Updated case location to #{caseLocation}"

                  data.followups[caseLocation].allCases.push malariaCase
                  data.followups["ALL"].allCases.push malariaCase

                  if malariaCase["Facility"]?.complete is "true" or malariaCase["Facility"]?.complete is true
                    data.followups[caseLocation].casesWithCompleteFacilityVisit.push malariaCase
                    data.followups["ALL"].casesWithCompleteFacilityVisit.push malariaCase
                  else
                    data.followups[caseLocation].casesWithoutCompleteFacilityVisit.push malariaCase
                    data.followups["ALL"].casesWithoutCompleteFacilityVisit.push malariaCase

                  if malariaCase.completeHouseholdVisit()
                    data.followups[caseLocation].casesWithCompleteHouseholdVisit.push malariaCase
                    data.followups["ALL"].casesWithCompleteHouseholdVisit.push malariaCase
                  else
                    data.followups[caseLocation].casesWithoutCompleteHouseholdVisit.push malariaCase
                    data.followups["ALL"].casesWithoutCompleteHouseholdVisit.push malariaCase

                  unless malariaCase["USSD Notification"]?
                    data.followups[caseLocation].missingUssdNotification.push malariaCase
                    data.followups["ALL"].missingUssdNotification.push malariaCase
                  unless malariaCase["Case Notification"]?
                    data.followups[caseLocation].missingCaseNotification.push malariaCase
                    data.followups["ALL"].missingCaseNotification.push malariaCase
                  if malariaCase.notCompleteFacilityAfter24Hours()
                    data.followups[caseLocation].noFacilityFollowupWithin24Hours.push malariaCase
                    data.followups["ALL"].noFacilityFollowupWithin24Hours.push malariaCase

                  if malariaCase.notFollowedUpAfter48Hours()
                    data.followups[caseLocation].noHouseholdFollowupWithin48Hours.push malariaCase
                    data.followups["ALL"].noHouseholdFollowupWithin48Hours.push malariaCase
                  

                  if malariaCase["Household"]?.CaseInvestigationStatus is "Lost To Followup"
                    data.followups[caseLocation].lostToFollowUp.push malariaCase
                    data.followups["ALL"].lostToFollowUp.push malariaCase

                  if malariaCase["Household"]?.HasThisCaseAlreadyBeenInvestigatedDueToAnotherHouseholdInvestigation is "Yes"
                    data.followups[caseLocation].casesInvestigatedDueToAnotherCaseInvestigation.push malariaCase
                    data.followups["ALL"].casesInvestigatedDueToAnotherCaseInvestigation.push malariaCase

                  if malariaCase["Facility"]?.DmsoVerifiedResults is "Duplicate notification"
                    data.followups[caseLocation].multipleNotified.push malariaCase
                    data.followups["ALL"].multipleNotified.push malariaCase

                  if malariaCase["Facility"]?.DmsoVerifiedResults is "False positive"
                    data.followups[caseLocation].falsePositive.push malariaCase
                    data.followups["ALL"].falsePositive.push malariaCase

                  if malariaCase["Facility"]?.DmsoVerifiedResults !="False positive" and malariaCase["Facility"]?.DmsoVerifiedResults != "Duplicate notification"
                    data.followups[caseLocation].casesForInvestigation.push malariaCase
                    data.followups["ALL"].casesForInvestigation.push malariaCase
                  
                  if malariaCase["Facility"]?.DmsoVerifiedResults != "False positive" and malariaCase["Facility"]?.DmsoVerifiedResults != "Duplicate notification" and malariaCase["Household"]?.CaseInvestigationStatus != "Lost To Followup"
                    data.followups[caseLocation].casesForFullInvestigation.push malariaCase
                    data.followups["ALL"].casesForFullInvestigation.push malariaCase
                  
                  if malariaCase["Household Members"].length > 1
                    positiveCases = (cases for cases in malariaCase["Household Members"] when ( cases.MalariaMrdtTestResults&&cases?.MalariaMrdtTestResults!='Negative')||(cases?.MalariaMicroscopyTestResults&&cases?.MalariaMicroscopyTestResults!='Negative'))
                    if positiveCases.length > 1
                      data.followups[caseLocation].houseWithMoreThanOnePositiveCase.push malariaCase
                      data.followups["ALL"].houseWithMoreThanOnePositiveCase.push malariaCase

                  if malariaCase['Household Members'].length > 0
                    malariaCase['Household Members'].forEach (member) ->
                      if Object.keys(member).find(((key) ->
                        key.includes 'Time Outside Zanzibar'
                      ))
                        data.individualClassification[caseLocation].withTravelHistory.push malariaCase
                        data.individualClassification["ALL"].withTravelHistory.push malariaCase
                      if member.CaseCategory
                        data.individualClassification[caseLocation][member.CaseCategory.toLowerCase()].push malariaCase
                        data.individualClassification['ALL'][member.CaseCategory.toLowerCase()].push malariaCase
                      return

                  if malariaCase.followedUp()
                    data.passiveCases[caseLocation].indexCases.push malariaCase
                    data.passiveCases["ALL"].indexCases.push malariaCase

                    completeIndexCaseHouseholdMembers = malariaCase.completeIndexCaseHouseholdMembers()
                    data.passiveCases[caseLocation].indexCaseHouseholdMembers =  data.passiveCases[caseLocation].indexCaseHouseholdMembers.concat(completeIndexCaseHouseholdMembers)
                    data.passiveCases["ALL"].indexCaseHouseholdMembers =  data.passiveCases["ALL"].indexCaseHouseholdMembers.concat(completeIndexCaseHouseholdMembers)

                    positiveIndividualsAtIndexHousehold = malariaCase.positiveIndividualsAtIndexHousehold()
                    data.passiveCases[caseLocation].positiveIndividualsAtIndexHousehold = data.passiveCases[caseLocation].positiveIndividualsAtIndexHousehold.concat positiveIndividualsAtIndexHousehold
                    data.passiveCases["ALL"].positiveIndividualsAtIndexHousehold = data.passiveCases["ALL"].positiveIndividualsAtIndexHousehold.concat positiveIndividualsAtIndexHousehold

                    completeNeighborHouseholds = malariaCase.completeNeighborHouseholds()
                    data.passiveCases[caseLocation].neighborHouseholds =  data.passiveCases[caseLocation].neighborHouseholds.concat(completeNeighborHouseholds)
                    data.passiveCases["ALL"].neighborHouseholds =  data.passiveCases["ALL"].neighborHouseholds.concat(completeNeighborHouseholds)

                    completeNeighborHouseholdMembers = malariaCase.completeNeighborHouseholdMembers()
                    data.passiveCases[caseLocation].neighborHouseholdMembers =  data.passiveCases[caseLocation].neighborHouseholdMembers.concat(completeNeighborHouseholdMembers)
                    data.passiveCases["ALL"].neighborHouseholdMembers =  data.passiveCases["ALL"].neighborHouseholdMembers.concat(completeNeighborHouseholdMembers)

                    _.each malariaCase.positiveIndividualsIncludingIndex(), (positiveIndividual) ->
                      data.totalPositiveCases[caseLocation].push positiveIndividual
                      data.totalPositiveCases["ALL"].push positiveIndividual

                      if positiveIndividual.Age?
                        age = parseInt(positiveIndividual.Age)
                        if age < 5
                          data.ages[caseLocation].underFive.push positiveIndividual
                          data.ages["ALL"].underFive.push positiveIndividual
                        else if age < 15
                          data.ages[caseLocation].fiveToFifteen.push positiveIndividual
                          data.ages["ALL"].fiveToFifteen.push positiveIndividual
                        else if age < 25
                          data.ages[caseLocation].fifteenToTwentyFive.push positiveIndividual
                          data.ages["ALL"].fifteenToTwentyFive.push positiveIndividual
                        else if age >= 25
                          data.ages[caseLocation].overTwentyFive.push positiveIndividual
                          data.ages["ALL"].overTwentyFive.push positiveIndividual
                      else
                        data.ages[caseLocation].unknown.push positiveIndividual unless positiveIndividual.age
                        data.ages["ALL"].unknown.push positiveIndividual unless positiveIndividual.age

                      if positiveIndividual.Sex is "Male"
                        data.gender[caseLocation].male.push positiveIndividual
                        data.gender["ALL"].male.push positiveIndividual
                      else if positiveIndividual.Sex is "Female"
                        data.gender[caseLocation].female.push positiveIndividual
                        data.gender["ALL"].female.push positiveIndividual
                      else
                        data.gender[caseLocation].unknown.push positiveIndividual
                        data.gender["ALL"].unknown.push positiveIndividual

                      if (positiveIndividual.SleptunderLLINlastnight is "Yes" || positiveIndividual.IndexcaseSleptunderLLINlastnight is "Yes")
                        data.netsAndIRS[caseLocation].sleptUnderNet.push positiveIndividual
                        data.netsAndIRS["ALL"].sleptUnderNet.push positiveIndividual

                      if (positiveIndividual.LastdateofIRS and positiveIndividual.LastdateofIRS.match(/\d\d\d\d-\d\d-\d\d/))
                        # if date of spraying is less than X months
                        if (new moment).subtract(Coconut.IRSThresholdInMonths,'months') < (new moment(positiveIndividual.LastdateofIRS))
                          data.netsAndIRS[caseLocation].recentIRS.push positiveIndividual
                          data.netsAndIRS["ALL"].recentIRS.push positiveIndividual

                      if positiveIndividual.TravelledOvernightInPastMonth?
                        if positiveIndividual.TravelledOvernightInPastMonth is "Unknown"
                          positiveIndividual.TravelledOvernightInPastMonth = "Not Applicable"
                        data.travel[caseLocation][positiveIndividual.TravelledOvernightInPastMonth].push positiveIndividual
                        data.travel[caseLocation]["Any travel"].push positiveIndividual if positiveIndividual.TravelledOvernightInPastMonth.match(/Yes/)
                        data.travel["ALL"][positiveIndividual.TravelledOvernightInPastMonth].push positiveIndividual
                        data.travel["ALL"]["Any travel"].push positiveIndividual if positiveIndividual.TravelledOvernightInPastMonth.match(/Yes/)
                      else if positiveIndividual.OvernightTravelinpastmonth
                        if positiveIndividual.OvernightTravelinpastmonth is "Unknown"
                          positiveIndividual.OvernightTravelinpastmonth = "Not Applicable"
                        data.travel[caseLocation][positiveIndividual.OvernightTravelinpastmonth].push positiveIndividual
                        data.travel[caseLocation]["Any travel"].push positiveIndividual if positiveIndividual.OvernightTravelinpastmonth.match(/Yes/)
                        data.travel["ALL"][positiveIndividual.OvernightTravelinpastmonth].push positiveIndividual
                        data.travel["ALL"]["Any travel"].push positiveIndividual if positiveIndividual.OvernightTravelinpastmonth.match(/Yes/)


                # Iterate through each malaria case in the result rows
                _.each result.rows, (malariaCase) ->
                    # Extract facility-district property from the malariaCase document
                    caseLocation = extractFacilityDistrict(malariaCase)

                    # Check if the case location is not found in the follow-ups data
                    unless data.followups[caseLocation]
                        # Log a message indicating that the case location was not found
                        console.log "Case location #{caseLocation} not found"

                        # Search for the case location in the GeoHierarchy with the specified aggregation level
                        # and update the case location with the found alias or use "UNKNOWN" if not found
                        caseLocation = GeoHierarchy.find(caseLocation, options.aggregationLevel)?[0]?.name or "UNKNOWN"

                        # Log a message indicating the updated case location
                        console.log "Updated case location to #{caseLocation}"

                    # Push the current malariaCase to the specific follow-ups location and the "ALL" category
                    data.followups[caseLocation].allShoki.push malariaCase
                    data.followups["ALL"].allShoki.push malariaCase


                # Iterate through each malaria case in the result rows
                _.each result.rows, (malariaCase) ->
                    # Extract facility-district property from the malariaCase document
                    caseLocation = extractFacilityDistrict(malariaCase)

                    # Check if the case location is not found in the follow-ups data
                    unless data.followups[caseLocation]
                        # Log a message indicating that the case location was not found
                        console.log "Case location #{caseLocation} not found"

                        # Search for the case location in the GeoHierarchy with the specified aggregation level
                        # and update the case location with the found alias or use "UNKNOWN" if not found
                        caseLocation = GeoHierarchy.find(caseLocation, options.aggregationLevel)?[0]?.name or "UNKNOWN"

                        # Log a message indicating the updated case location
                        console.log "Updated case location to #{caseLocation}"

                    # Push the current malariaCase to the specific follow-ups location and the "ALL" category
                    data.followups[caseLocation].allShoki.push malariaCase
                    data.followups["ALL"].allShoki.push malariaCase

                # Call the method with the appropriate options
                reportsInstance.getCasesNotifiedWith24Hrs(options)
                  .then (notificationResult) =>
                    if notificationResult?.rows?.length > 0
                      # Iterate through each malaria case in the notificationResult rows
                      _.each notificationResult.rows, (notification) ->
                        # Extract facility-district property from the malariaCase document
                        notificationCaseLocation = extractFacilityDistrict(notification)

                        # Check if the case location is not found in the follow-ups data
                        unless data.followups[notificationCaseLocation]
                          # Log a message indicating that the case location was not found
                          console.log "Case location #{notificationCaseLocation} not found"

                          # Search for the case location in the GeoHierarchy with the specified aggregation level
                          # and update the case location with the found alias or use "UNKNOWN" if not found
                          notificationCaseLocation = GeoHierarchy.find(notificationCaseLocation, options.aggregationLevel)?[0]?.name or "UNKNOWN"

                          # Log a message indicating the updated case location
                          console.log "Updated case location to #{notificationCaseLocation}"

                        # Push the current malariaCase to the specific follow-ups location and the "ALL" category
                        data.followups[notificationCaseLocation].caseNotifiedWith24HRS.push notification
                        data.followups["ALL"].caseNotifiedWith24HRS.push notification

                      options.finished?(data)
                      resolve(data)
            # END NOW 
          else
            console.log("No rows found in the result.")
        .catch (error) =>
          # Handle errors here
          console.error(error)

  @specimensAggregatedForAnalysis = (options) =>
    new Promise (resolve, reject) =>

      data = {}

      options.aggregationLevel ||= "DISTRICT"

      # Hack required because we have multiple success callbacks
      options.finished = options.success

      # Refactor to use reporting database - will be faster and centralize calculations like is the case complete?

      Reports.getSpecimens _.extend options,
        success: (cases) =>
          data.identificationAndAbundance = {}
          data.vectorsPerMethodPerSite = {}

          # Setup hashes for each table
          aggregationNames = GeoHierarchy.all options.aggregationLevel
          aggregationNames.push("UNKNOWN")
          aggregationNames.push("ALL")
          _.each aggregationNames, (aggregationName) ->
            data.identificationAndAbundance[aggregationName] =
              allVectors: []
              anGambiaeComplex: []
              anFunestus: []
              anCostani: []
              anMaculipalpis: []
              anNili: []
              otherSpecies: []
              total: []

            data.vectorsPerMethodPerSite[aggregationName] =
              humanLandingCatchAnGambiae: []
              humanLandingCatchAnFunestus:[]
              pyrethrumSprayCatchAnGambiae: []
              pyrethrumSprayCatchAnFunestus:[]
              pitTrapAnGambiae: []
              pitTrapAnFunestus:[]
              cdcLightTrapAnGambiae: []
              cdcLightTrapAnFunestus:[]
              totalAnGambiae: []
              totalAnFunestus :[]
              

          _.each cases, (specimen) ->
            caseLocation = specimen.locationBy(options.aggregationLevel).trim() || "UNKNOWN"
            data.identificationAndAbundance["ALL"].total.push specimen
            data.identificationAndAbundance[caseLocation].total.push specimen
            if(specimen.morphologicalIdentification is "An gambiae complex")
              data.identificationAndAbundance[caseLocation].anGambiaeComplex.push specimen
              data.identificationAndAbundance["ALL"].anGambiaeComplex.push specimen
              data.vectorsPerMethodPerSite[caseLocation].totalAnGambiae.push specimen
              data.vectorsPerMethodPerSite["ALL"].totalAnGambiae.push specimen
              if(specimen.methodOfCollection is "Pyrethrum-Spray Catch (PSC)")
                data.vectorsPerMethodPerSite[caseLocation].pyrethrumSprayCatchAnGambiae.push specimen
                data.vectorsPerMethodPerSite["ALL"].pyrethrumSprayCatchAnGambiae.push specimen
              if(specimen.methodOfCollection is "Human-Landing Catch (HLC)")
                data.vectorsPerMethodPerSite[caseLocation].humanLandingCatchAnGambiae.push specimen
                data.vectorsPerMethodPerSite["ALL"].humanLandingCatchAnGambiae.push specimen
              if(specimen.methodOfCollection is "Pit-trap Catches (PTC)")
                data.vectorsPerMethodPerSite[caseLocation].pitTrapAnGambiae.push specimen
                data.vectorsPerMethodPerSite["ALL"].pitTrapAnGambiae.push specimen
              if(specimen.methodOfCollection is "CDC-Light Trap Catches(LTC)")
                data.vectorsPerMethodPerSite[caseLocation].cdcLightTrapAnGambiae.push specimen
                data.vectorsPerMethodPerSite["ALL"].cdcLightTrapAnGambiae.push specimen
            if(specimen.morphologicalIdentification is "An funestus")
              data.identificationAndAbundance[caseLocation].anFunestus.push specimen
              data.identificationAndAbundance["ALL"].anFunestus.push specimen
              data.vectorsPerMethodPerSite[caseLocation].totalAnFunestus.push specimen
              data.vectorsPerMethodPerSite["ALL"].totalAnFunestus.push specimen
              if(specimen.methodOfCollection is "Pyrethrum-Spray Catch (PSC)")
                data.vectorsPerMethodPerSite[caseLocation].pyrethrumSprayCatchAnFunestus.push specimen
                data.vectorsPerMethodPerSite["ALL"].pyrethrumSprayCatchAnFunestus.push specimen
              if(specimen.methodOfCollection is "Human-Landing Catch (HLC)")
                data.vectorsPerMethodPerSite[caseLocation].humanLandingCatchAnFunestus.push specimen
                data.vectorsPerMethodPerSite["ALL"].humanLandingCatchAnFunestus.push specimen
              if(specimen.methodOfCollection is "Pit-trap Catches (PTC)")
                data.vectorsPerMethodPerSite[caseLocation].pitTrapAnFunestus.push specimen
                data.vectorsPerMethodPerSite["ALL"].pitTrapAnFunestus.push specimen
              if(specimen.methodOfCollection is "CDC-Light Trap Catches(LTC)")
                data.vectorsPerMethodPerSite[caseLocation].cdcLightTrapAnFunestus.push specimen
                data.vectorsPerMethodPerSite["ALL"].cdcLightTrapAnFunestus.push specimen
            if(specimen.morphologicalIdentification is "An costani")
              data.identificationAndAbundance[caseLocation].anCostani.push specimen
              data.identificationAndAbundance["ALL"].anCostani.push specimen
            if(specimen.morphologicalIdentification is "An maculipalpis")
              data.identificationAndAbundance[caseLocation].anMaculipalpis.push specimen
              data.identificationAndAbundance["ALL"].anMaculipalpis.push specimen
            if(specimen.morphologicalIdentification is "An nili")
              data.identificationAndAbundance[caseLocation].anNili.push specimen
              data.identificationAndAbundance["ALL"].anNili.push specimen
            if(specimen.morphologicalIdentification is "Other species")
              data.identificationAndAbundance[caseLocation].otherSpecies.push specimen
              data.identificationAndAbundance["ALL"].otherSpecies.push specimen
            data.identificationAndAbundance[caseLocation].allVectors.push specimen
            data.identificationAndAbundance["ALL"].allVectors.push specimen
          options.finished?(data)
          resolve(data)

  @systemErrors: (options) ->
    Coconut.database.query "errorsByDate",
      # Note that these seem reversed due to descending order
      startkey: options?.endDate || moment().format("YYYY-MM-DD")
      endkey: options?.startDate || moment().subtract(1,'days').format("YYYY-MM-DD")
      descending: true
      include_docs: true
    .catch (error) -> console.error
    .then (result) ->
      errorsByType = {}
      _.chain(result.rows)
        .pluck("doc")
        .each (error) ->
          if errorsByType[error.message]?
            errorsByType[error.message].count++
          else
            errorsByType[error.message]= {}
            errorsByType[error.message].count = 0
            errorsByType[error.message]["Most Recent"] = error.datetime
            errorsByType[error.message]["Source"] = error.source
            errorsByType[error.message]["Most Recent"] = error.datetime if errorsByType[error.message]["Most Recent"] < error.datetime
      options.success(errorsByType)

  @casesWithoutCompleteHouseholdVisit: (options) ->
    reports = new Reports()
    # TODO casesAggregatedForAnalysis should be static
    reports.casesAggregatedForAnalysis
      startDate: options?.startDate || moment().subtract(9,'days').format("YYYY-MM-DD")
      endDate: options?.endDate || moment().subtract(2,'days').format("YYYY-MM-DD")
      mostSpecificLocation: options.mostSpecificLocation
      success: (cases) ->
        options.success(cases.followups["ALL"]?.casesWithoutCompleteHouseholdVisit)

  @unknownDistricts: (options) ->
    reports = new Reports()
    # TODO casesAggregatedForAnalysis should be static
    reports.casesAggregatedForAnalysis
      startDate: options?.startDate || moment().subtract(14,'days').format("YYYY-MM-DD")
      endDate: options?.endDate || moment().subtract(7,'days').format("YYYY-MM-DD")
      mostSpecificLocation: options.mostSpecificLocation
      success: (cases) ->
        options.success(cases.followups["UNKNOWN"]?.casesWithoutCompleteHouseholdVisit)

  @userAnalysisTest: ->
    @userAnalysis
      startDate: "2014-10-01"
      endDate: "2014-12-01"
      success: (result) ->

  @userAnalysis: (options) ->
    @userAnalysisForUsers
      # Pass list of usernames
      usernames:  Users.map (user) -> user.username()
      success: options.success
      startDate: options.startDate
      endDate: options.endDate

  @userAnalysisForUsers: (options) ->
    usernames = options.usernames
    Coconut.medianTimeWithHalves = (values) =>
      return [values[0],values[0],values[0]] if values.length is 1

      # Remove negative values, these are probably due to cleaning
      values = _(values).filter (value) -> value >= 0
      values = _(values).compact()

      values.sort  (a,b)=> return a - b
      half = Math.floor values.length/2
      if values.length % 2 #odd
        median = values[half]
        return [median,values[0..half],values[half...]]
      else # even
        median = (values[half-1] + values[half]) / 2.0
        return [median, values[0..half-1],values[half...]]

    Coconut.medianTime = (values)=>
      Coconut.medianTimeWithHalves(values)[0]

    Coconut.medianTimeFormatted = (times) ->
      duration = moment.duration(Coconut.medianTime(times))
      unless duration.isValid() then "-" else duration.humanize()

    Coconut.quartiles = (values) ->
      [median,h1Values,h2Values] = Coconut.medianTimeWithHalves(values)
      [
        Coconut.medianTime(h1Values)
        median
        Coconut.medianTime(h2Values)
      ]

    Coconut.quartile1Time = (values) -> Coconut.quartiles(values)[0]
    Coconut.quartile3Time = (values) -> Coconut.quartiles(values)[2]

    Coconut.quartile1TimeFormatted = (times) ->
      duration = moment.duration(Coconut.quartile1Time(times))
      unless duration.isValid() then "-" else duration.humanize()

    Coconut.quartile3TimeFormatted = (times) ->
      duration = moment.duration(Coconut.quartile3Time(times))
      unless duration.isValid() then "-" else duration.humanize()

    Coconut.averageTime = (times) ->
      sum = 0
      amount = 0
      _(times).each (time) ->
        if time?
          amount += 1
          sum += time

      return 0 if amount is 0
      return sum/amount

    Coconut.averageTimeFormatted = (times) ->
      duration = moment.duration(Coconut.averageTime(times))
      if duration.isValid()
        return duration.humanize()
      else
        return "-"

    # Initialize the dataByUser object
    dataByUser = {}
    _(usernames).each (username) ->
      dataByUser[username] = {
        userId: username
        caseIds: {}
        cases: {}
        casesWithoutCompleteFacilityAfter24Hours: {}
        casesWithoutCompleteFacility: {}
        casesWithoutCompleteHouseholdAfter48Hours: {}
        casesWithoutCompleteHousehold: {}
        casesWithCompleteHousehold: {}
        timesFromSMSToCaseNotification: []
        timesFromCaseNotificationToCompleteFacility: []
        timesFromFacilityToCompleteHousehold: []
        timesFromSMSToCompleteHousehold: []
      }

    total = {
      caseIds: {}
      cases: {}
      casesWithoutCompleteFacilityAfter24Hours: {}
      casesWithoutCompleteFacility: {}
      casesWithoutCompleteHouseholdAfter48Hours: {}
      casesWithoutCompleteHousehold: {}
      casesWithCompleteHousehold: {}
      timesFromSMSToCaseNotification: []
      timesFromCaseNotificationToCompleteFacility: []
      timesFromFacilityToCompleteHousehold: []
      timesFromSMSToCompleteHousehold: []
    }

    dataByCase = {}

    # Get the the caseids for all of the results in the data range with the user id
    Coconut.database.query "resultsByDateWithUserAndCaseId",
      startkey: options.startDate
      endkey: options.endDate
      include_docs: false
    .catch (error) -> console.error error
    .then (results) ->
      _(results.rows).each (result) ->
        caseId = result.value[1]
        user = result.value[0]
        if user isnt ""
          dataByUser[user].caseIds[caseId] = true
          dataByUser[user].cases[caseId] = {}
          total.caseIds[caseId] = true
          total.cases[caseId] = {}

      _(dataByUser).each (userData,user) ->
        if _(dataByUser[user].cases).size() is 0
          delete dataByUser[user]

      successWhenDone = _.after _(dataByUser).size(), ->
        options.success
          dataByUser: dataByUser
          total: total
          dataByCase: dataByCase

      #return if no users with cases
      successWhenDone() if _.isEmpty(dataByUser)

      _(dataByUser).each (userData,user) ->
        # Get the time differences within each case
        caseIds = _(userData.cases).map (foo, caseId) -> caseId

        Coconut.database.query "cases",
          keys: caseIds
          include_docs: true
        .catch (error) ->
          console.error "Error finding cases: " + JSON.stringify error
        .then (result) ->
          caseId = null
          caseResults = []
          # Collect all of the results for each caseid, then create the case and process it
          _.each result?.rows, (row) ->
            if caseId? and caseId isnt row.key
              malariaCase = new Case
                caseID: caseId
                results: caseResults
              caseResults = []

              userData.cases[caseId] = malariaCase
              total.cases[caseId] = malariaCase

              if malariaCase.notCompleteFacilityAfter24Hours()
                userData.casesWithoutCompleteFacilityAfter24Hours[caseId] = malariaCase
                total.casesWithoutCompleteFacilityAfter24Hours[caseId] = malariaCase
              unless malariaCase.hasCompleteFacility()
                userData.casesWithoutCompleteFacility[caseId] = malariaCase
                total.casesWithoutCompleteFacility[caseId] = malariaCase

              if malariaCase.notFollowedUpAfter48Hours()
                userData.casesWithoutCompleteHouseholdAfter48Hours[caseId] = malariaCase
                total.casesWithoutCompleteHouseholdAfter48Hours[caseId] = malariaCase

              if malariaCase.followedUp()
                userData.casesWithCompleteHousehold[caseId] = malariaCase
                total.casesWithCompleteHousehold[caseId] = malariaCase
              else
                userData.casesWithoutCompleteHousehold[caseId] = malariaCase
                total.casesWithoutCompleteHousehold[caseId] = malariaCase

              _([
                "SMSToCaseNotification"
                "CaseNotificationToCompleteFacility"
                "FacilityToCompleteHousehold"
                "SMSToCompleteHousehold"
              ]).each (property) ->

                result = malariaCase["timeFrom#{property}"]()
                if result
                  userData["timesFrom#{property}"].push result
                  total["timesFrom#{property}"].push result
                  dataByCase[malariaCase.caseID] or= {}
                  dataByCase[malariaCase.caseID]["timesFrom#{property}"] = result

            caseResults.push row.doc
            caseId = row.key
          _(userData.cases).each (results,caseId) ->
            _([
              "SMSToCaseNotification"
              "CaseNotificationToCompleteFacility"
              "FacilityToCompleteHousehold"
              "SMSToCompleteHousehold"
            ]).each (property) ->

              _(["quartile1","median","quartile3"]).each (dataPoint) ->
                try
                  userData["#{dataPoint}TimeFrom#{property}"] = Coconut["#{dataPoint}TimeFormatted"](userData["timesFrom#{property}"])
                  userData["#{dataPoint}TimeFrom#{property}Seconds"] = Coconut["#{dataPoint}Time"](userData["timesFrom#{property}"])
                  total["#{dataPoint}TimeFrom#{property}"] = Coconut["#{dataPoint}TimeFormatted"](total["timesFrom#{property}"])
                  total["#{dataPoint}TimeFrom#{property}Seconds"] = Coconut["#{dataPoint}Time"](total["timesFrom#{property}"])
                catch error
                  console.error error
                  console.error "Error processing data for the following user:"
                  console.error userData

          successWhenDone()

  @aggregateWeeklyReports = (options) ->
    new Promise (resolve,reject) =>
      startDate = moment(options.startDate)
      startYear = startDate.format("GGGG") # ISO week year
      startWeek = startDate.format("WW")
      endDate = moment(options.endDate).endOf("day")
      endYear = endDate.format("GGGG")
      endWeek = endDate.format("WW")
      aggregationArea = options.aggregationArea
      aggregationPeriod = options.aggregationPeriod
      facilityType = options.facilityType or "All"
      Coconut.weeklyFacilityDatabase.query "weeklyDataBySubmitDate",
        startkey: [startYear,startWeek]
        endkey: [endYear,endWeek]
        include_docs: true
      .catch (error) -> console.error
      .then (results) =>
          cumulativeFields = {
            "All OPD < 5" : 0
            "Mal POS < 5" : 0
            "Mal NEG < 5" : 0
            "All OPD >= 5" : 0
            "Mal POS >= 5" : 0
            "Mal NEG >= 5" : 0
          }

          aggregatedData = {}
          errors = {}

          _(results.rows).each (row) =>
            weeklyReport = row.doc
            date = moment().year(weeklyReport.Year).isoWeek(weeklyReport.Week)
            period = Reports.getAggregationPeriodDate(aggregationPeriod,date)

            if facilityType isnt "All"
              return if GeoHierarchy.facilityType(weeklyReport.Facility) isnt facilityType.toUpperCase()

            areaNameFromReport = weeklyReport[aggregationArea]
            area = GeoHierarchy.findFirst(areaNameFromReport, aggregationArea)?.name

            unless area?
              errors["Missing #{aggregationArea}"] or= {}
              errors["Missing #{aggregationArea}"][areaNameFromReport] = row.doc
              console.error "Can't find #{aggregationArea} #{areaNameFromReport}"
              area = "UNKNOWN: #{weeklyReport.Zone}-#{weeklyReport.District}-#{areaNameFromReport}"
            aggregatedData[period] = {} unless aggregatedData[period]
            aggregatedData[period][area] = _(cumulativeFields).clone() unless aggregatedData[period][area]

            _(_(cumulativeFields).keys()).each (field) ->
              aggregatedData[period][area][field] += parseInt(weeklyReport[field])


            aggregatedData[period][area]["Reports submitted for period"] = 0 unless aggregatedData[period][area]["Reports submitted for period"]
            aggregatedData[period][area]["Reports submitted for period"] += 1

            endDayForReportPeriod = moment("#{weeklyReport.Year} #{weeklyReport.Week}","YYYY WW").endOf("isoweek")
            numberOfDaysSinceEndOfPeriodReportSubmitted = moment(weeklyReport["Submit Date"]).diff(endDayForReportPeriod,"days")

            aggregatedData[period][area]["Report submitted within 1 day"] = 0 unless aggregatedData[period][area]["Report submitted within 1 day"]
            aggregatedData[period][area]["Report submitted 1-3 days"] = 0 unless aggregatedData[period][area]["Report submitted 1-3 days"]
            aggregatedData[period][area]["Report submitted 3-5 days"] = 0 unless aggregatedData[period][area]["Report submitted 3-5 days"]
            aggregatedData[period][area]["Report submitted 5+ days"] = 0 unless aggregatedData[period][area]["Report submitted 5+ days"]

            if numberOfDaysSinceEndOfPeriodReportSubmitted <= 1
              aggregatedData[period][area]["Report submitted within 1 day"] +=1
            else if numberOfDaysSinceEndOfPeriodReportSubmitted > 1 and numberOfDaysSinceEndOfPeriodReportSubmitted <= 3
              aggregatedData[period][area]["Report submitted 1-3 days"] +=1
            else if numberOfDaysSinceEndOfPeriodReportSubmitted > 3 and numberOfDaysSinceEndOfPeriodReportSubmitted <= 5
              aggregatedData[period][area]["Report submitted 3-5 days"] +=1
            else if numberOfDaysSinceEndOfPeriodReportSubmitted > 5
              aggregatedData[period][area]["Report submitted 5+ days"] +=1

          result = 
            fields: _(cumulativeFields).keys()
            data: aggregatedData
            errors: errors

          options.success?(result)
          resolve(result)

  @positiveCasesAggregated= (options) =>
    new Promise (resolve, reject) =>
      results = {}

      aggregationAreasAndIndicators = {}

      for threshold in options.thresholds
        aggregationAreasAndIndicators[threshold.aggregationArea] or= {}
        aggregationAreasAndIndicators[threshold.aggregationArea][threshold.indicator] = true

      caseCounterData = await Coconut.reportingDatabase.query "caseCounter",
        startkey: [options.startDate]
        endkey: [options.endDate,{}]
        reduce: false
      .then (result) =>
        Promise.resolve(result.rows)

      for row in caseCounterData
        diagnosisDate = row.key[0]
        indicator = row.key[1]

        caseID = row.id[13..] # slice off the case_summary_ part

        indexCaseResult =
          caseID: caseID
          link: "#show/case/#{caseID}"
          # namesOfAdministrativeLevels
          # Nation, Island, Region, District, Shehia, Facility   EXAMPLE:
          #"ZANZIBAR","PEMBA","KUSINI PEMBA","MKOANI","WAMBAA","MWANAMASHUNGI
          district: row.key[5]
          shehia: row.key[6]
          facility: row.key[7]

        ###
        # Example
        aggregationAreasAndIndicators = 
        {
          "shehia":
            "Number Positive Cases Including Index": true
            "Number Positive Individuals Under 5": true
          "facility":
            "Number Positive Cases Including Index": true
            "Number Positive Individuals Under 5": true
        }
        ###
        for aggregationArea, indicators of aggregationAreasAndIndicators
          continue unless indexCaseResult[aggregationArea]
          for targetIndicator of indicators
            if indicator is targetIndicator
              _(row.value).times -> # add the case ID for each positive individual counted for this case
                results[aggregationArea] or= {}
                results[aggregationArea][indexCaseResult[aggregationArea]] or= {}
                results[aggregationArea][indexCaseResult[aggregationArea]][indicator] or= []
                results[aggregationArea][indexCaseResult[aggregationArea]][indicator].push indexCaseResult

      resolve(results)


  @aggregatePositiveFacilityCases = (options) ->
    aggregationArea = options.aggregationArea
    aggregationPeriod = options.aggregationPeriod


    Coconut.database.query "positiveFacilityCasesByDate",
      startkey: options.startDate
      endkey: options.endDate
      include_docs: false
    .catch (error) -> console.error
    .then (result) ->
      aggregatedData = {}

      _.each result.rows, (row) ->
        date = moment(row.key)

        period = switch aggregationPeriod
          when "Week" then date.format("YYYY-WW")
          when "Month" then date.format("YYYY-MM")
          when "Quarter" then "#{date.format("YYYY")}q#{Math.floor((date.month() + 3) / 3)}"
          when "Year" then date.format("YYYY")

        [caseId, facility, shehia, village] = row.value
        data =
          Zone: GeoHierarchy.getZone(facility)
          District: GeoHierarchy.getDistrict(facility)
          Facility: row.value[1]
          Shehia: row.value[2]
          Village: row.value[3]
          Age: row.value[4]
          CaseId: row.value[0]

        area = data[aggregationArea]
        if area is null
          area = "Unknown"

        aggregatedData[period] = {} unless aggregatedData[period]
        aggregatedData[period][area] = [] unless aggregatedData[period][area]
        aggregatedData[period][area].push data

      options.success aggregatedData

  @aggregateWeeklyReportsAndFacilityCases = (options) =>
    options.localSuccess = options.success
    #Note that the order of the commands below is confusing
    #
    # This is what is called after doing the aggregateWeeklyReports
    options.success = (data) =>
      # This is what is called after doing the aggregatePositiveFacilityCases
      options.success = (facilityCaseData) ->
        data.fields.push "Facility Followed-Up Positive Cases"
        _(facilityCaseData).each (areas, period) ->
          _(areas).each (positiveFacilityCaseData, area) ->
            data.data[period] = {} unless data.data[period]
            data.data[period][area] = {} unless data.data[period][area]
            data.data[period][area]["Facility Followed-Up Positive Cases"] = _(positiveFacilityCaseData).pluck "CaseId"
        options.localSuccess data

      @aggregatePositiveFacilityCases options
    @aggregateWeeklyReports options

  @aggregateWeeklyReportsAndFacilityTimeliness = (options) =>
    new Promise (resolve, reject) =>

      data = await @aggregateWeeklyReports(options)
        .catch (error) => reject(error)

      facilityCaseData = await @aggregateTimelinessForCases(options)
        .catch (error) => reject(error)

      _(facilityCaseData).each (areaData, period) ->
        _(areaData).each (caseData, area) ->
          data.data[period] = {} unless data.data[period]
          data.data[period][area] = {} unless data.data[period][area]
          _([
            "daysBetweenPositiveResultAndNotificationFromFacility"
            "daysFromCaseNotificationToCompleteFacility"
            "daysFromSMSToCompleteHousehold"
            "numberHouseholdOrNeighborMembers"
            "numberHouseholdOrNeighborMembersTested"
            "numberPositiveIndividualsAtIndexHouseholdAndNeighborHouseholds"
            "hasCompleteFacility"
            "casesNotified"
            "householdFollowedUp"
            "followedUpWithin48Hours"
          ]).each (property) ->
            data.data[period][area][property] = caseData[property]
      resolve(data)


  @mostSpecificLocationSelected: ->
    mostSpecificLocationType = "region"
    mostSpecificLocationValue = "ALL"
    _.each @locationTypes, (locationType) ->
      unless this[locationType] is "ALL"
        mostSpecificLocationType = locationType
        mostSpecificLocationValue = this[locationType]
    return {
      type: mostSpecificLocationType
      name: mostSpecificLocationValue
    }


  @aggregateTimelinessForCases = (options) ->
    new Promise (resolve, reject) =>
      aggregationArea = options.aggregationArea
      aggregationPeriod = options.aggregationPeriod
      facilityType = options.facilityType

      Coconut.database.query "positiveFacilityCasesByDate",
        startkey: options.startDate
        endkey: options.endDate
        include_docs: false
      .catch (error) -> console.error
      .then (result) ->
        aggregatedData = {}

        _.each result.rows, (row) ->
          date = moment(row.key)

          period = Reports.getAggregationPeriodDate(aggregationPeriod,date)

          caseId = row.value[0]
          if caseId is null
            console.log "Case missing case ID: #{row.id}, skipping"
            return
          facility = row.value[1]

          if facilityType isnt "All"
            return if GeoHierarchy.facilityType(facility) isnt facilityType.toUpperCase()

          area = switch aggregationArea
            when "Zone" then GeoHierarchy.getZone(facility)
            when "District" then GeoHierarchy.getDistrict(facility)
            when "Facility" then facility
          area = "Unknown" if area is null

          aggregatedData[period] = {} unless aggregatedData[period]
          aggregatedData[period][area] = {} unless aggregatedData[period][area]
          aggregatedData[period][area]["cases"] = [] unless aggregatedData[period][area]["cases"]
          aggregatedData[period][area]["cases"].push caseId

        caseIdsToFetch = _.chain(aggregatedData).map (areaData,period) ->
           _(areaData).map (caseData,area) ->
            caseData.cases
        .flatten()
        .uniq()
        .value()

        Coconut.database.query "cases",
          keys: caseIdsToFetch
          include_docs: true
        .catch (error) -> reject(error)
        .then (result) =>
          cases = {}
          _.chain(result.rows).groupBy (row) =>
            row.key
          .each (resultsByCaseID) =>
            cases[resultsByCaseID[0].key] = new Case
              results: _.pluck resultsByCaseID, "doc"

          _(aggregatedData).each (areaData,period) ->
            _(areaData).each (caseData,area) ->
              _(caseData.cases).each (caseId) ->
                _([
                  "daysBetweenPositiveResultAndNotificationFromFacility"
                  "daysFromCaseNotificationToCompleteFacility"
                  "daysFromSMSToCompleteHousehold"
                ]).each (property) ->
                  aggregatedData[period][area][property] = [] unless aggregatedData[period][area][property]
                  value = cases[caseId][property]()
                  aggregatedData[period][area][property].push value if value?

                _([
                  "numberHouseholdMembersTestedAndUntested"
                  "numberHouseholdMembersTested"
                  "numberPositiveIndividuals"
                ]).each (property) ->
                  aggregatedData[period][area][property] = 0 unless aggregatedData[period][area][property]

                  aggregatedData[period][area][property]+= cases[caseId][property]()

                aggregatedData[period][area]["householdFollowedUp"] = 0 unless aggregatedData[period][area]["householdFollowedUp"]
                aggregatedData[period][area]["householdFollowedUp"]+= 1 if cases[caseId].followedUp()

                _(["hasCompleteFacility","followedUpWithin48Hours"]).each (property) ->
                  aggregatedData[period][area][property] = [] unless aggregatedData[period][area][property]
                  aggregatedData[period][area][property].push caseId if cases[caseId][property]()

                aggregatedData[period][area]["casesNotified"] = [] unless aggregatedData[period][area]["casesNotified"]
                aggregatedData[period][area]["casesNotified"].push caseId
            resolve(aggregatedData)


  @getAggregationPeriodDate = (aggregationPeriod,date) ->
    switch aggregationPeriod
      when "Week" then date.format("GGGG-WW")
      when "Month" then date.format("YYYY-MM")
      when "Quarter" then "#{date.format("YYYY")}q#{Math.floor((date.month() + 3) / 3)}"
      when "Year" then date.format("YYYY")


  @getIssues = (options) ->
    startDate = moment(options.startDate).format(Coconut.config.dateFormat)
    endDate = moment(options.endDate).endOf("day").format(Coconut.config.dateFormat)

    issueTypes = [
      "issue"
      "threshold"
    ]

    issues = []

    finished = _.after issueTypes.length, ->
      options.success(issues)

    _(issueTypes).each (prefix) ->
      Coconut.database.allDocs
        startkey: "#{prefix}-#{startDate}"
        endkey: "#{prefix}-#{endDate}-\ufff0"
        include_docs: true
      .catch (error) ->
        options.error(error)
      .then (result) =>
          issues = issues.concat _(result.rows).pluck "doc"
          finished()

module.exports = Reports
