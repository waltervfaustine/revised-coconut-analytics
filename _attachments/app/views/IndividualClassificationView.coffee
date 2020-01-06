_ = require 'underscore'
$ = require 'jquery'
require('jquery-ui')
Backbone = require 'backbone'
Backbone.$  = $

global.jQuery = require 'jquery'
require 'tablesorter'

Reports = require '../models/Reports'
CaseView = require './CaseView'
UserCollection = require '../models/UserCollection'

class IndividualClassificationView extends Backbone.View
  el: "#content"

  events:
    "click div.analysis.dropDownBtn": "showDropDown"
    "click #switch-details": "toggleDetails"
    "click #switch-unknown": "toggleGenderUnknown"
    "click button.caseBtn": "showCaseDialog"
    "click button#closeDialog": "closeDialog"
    "change [name=aggregationType]": "updateAnalysis"

  toggleDetails: (e)->
    $(".details").toggle()

  toggleGenderUnknown: (e)->
    $('.gender-unknown').toggle()

  showDropDown: (e) =>
    $target =  $(e.target).closest('.analysis')
    $target.next(".analysis-report").slideToggle()
    if ($target.find("i").hasClass('mdi-play'))
       $target.find("i").switchClass('mdi-play','mdi-menu-down-outline')
    else
       $target.find("i").switchClass('mdi-menu-down-outline','mdi-play')

  showCaseDialog: (e) ->
    caseID = $(e.target).parent().attr('id') || $(e.target).attr('id')
    CaseView.showCaseDialog
      caseID: caseID
      success: ->
    return false

  closeDialog: () ->
    caseDialog.close() if caseDialog.open

  updateAnalysis: (e) ->
    Coconut.router.reportViewOptions.aggregationLevel = $("[name=aggregationType]:checked").val()
    @render()

  render: =>
    @options = $.extend({},Coconut.router.reportViewOptions)
    @categories = [
      "Indigenous"
      "Imported"
      "Introduced"
      "Induced"
      "Relapsing"
    ]

    $('#analysis-spinner').show()
    HTMLHelpers.ChangeTitle("Reports: Individual Classification")
    @$el.html "
      <style>
        td button.same-cell-disaggregatable{ float:right;}
        .mdl-data-table th { padding: 0 6px}
        #classification th.mdl-data-table__cell--non-numeric.mdl-data-table__cell--non-numeric { text-align: right }
      </style>
      <dialog id='caseDialog'></dialog>
      <div id='dateSelector'></div>
      <div id='classification'>
        <!--
        <hr/>
        Aggregation Type:
        <input name='aggregationType' type='radio' #{if Coconut.router.reportViewOptions.aggregationLevel is "None" then "checked='true'" else ""} value='None'>&nbsp; None</input>
        <input name='aggregationType' type='radio' #{if Coconut.router.reportViewOptions.aggregationLevel is "District" then "checked='true'" else ""} value='District'>&nbsp; District</input>
        <input name='aggregationType' type='radio' #{if Coconut.router.reportViewOptions.aggregationLevel is "Shehia" then "checked='true'" else ""}  value='Shehia'>&nbsp; Shehia</input>
        <input name='aggregationType' type='radio' #{if Coconut.router.reportViewOptions.aggregationLevel is "Officer" then "checked='true'" else ""}  value='Office'>&nbsp; Malaria Officer</input>
        <div style='font-style:italic; margin-top: 10px'>Click on arrow button/title to show table.</div>
        <hr/>
        -->
      </div>
      <div id='messages'>
      </div>

    "
    @addTables()

  addTables: =>
    Coconut.database.query "positiveIndividualsByDiagnosisDate",
      startkey: @options.startDate
      endkey: @options.endDate
    .then (result) =>
      @positiveIndividualsByDiagnosisDate = result.rows

      @all()

      @loadCaseSummaryData().then =>

        @district()
        #@zone()
        @officer()

  dropDownButton: (name) =>
    @$("#classification").append "
      <div class='analysis dropDownBtn'>
        <div class='report-subtitle'>
          <button class='mdl-button mdl-js-button mdl-button--icon'>
            <i class='mdi mdi-play mdi-24px'></i>
          </button>
          #{name}
        </div>
      </div>
    "

  all: =>

    $("#analysis-spinner").hide()

    aggregated = {}

    for category in @categories
      aggregated[category] = []

    for row in @positiveIndividualsByDiagnosisDate
      aggregated[row.value[1]].push row.value[0]

    @dropDownButton("All")

    @$("#classification").append @createTable @categories, "
      <tr>
      #{
        (for category in @categories
          "
            <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(aggregated[category])}</td>
          "
        ).join("")
      }
      </tr>
    ", "all-table"

    # This is for MDL switch
    componentHandler.upgradeAllRegistered()

  loadCaseSummaryData: =>
    caseIds = _(@positiveIndividualsByDiagnosisDate).map (row) =>  row.value[0]
    caseDocIdsInReportingDatabase = _(caseIds).map (caseId) => "case_summary_#{caseId}"
    @districtForCase = {}
    @zoneForCase = {}
    @officerForCase = {}

    Coconut.reportingDatabase.allDocs
      keys: caseDocIdsInReportingDatabase
      include_docs: true
    .then (result) =>
      console.log result
      for row in result.rows
        malariaCase = row.doc
        console.log malariaCase
        district = malariaCase["District (if no household district uses facility)"]
        @districtForCase[malariaCase["Malaria Case ID"]] = district

        #@zoneForCase[malariaCase["Malaria Case ID"]] = GeoHierarchy.getZoneForDistrict(district)

        @officerForCase[malariaCase["Malaria Case ID"]] = Coconut.nameByUsername[(malariaCase["Household: User"])]


  district: => 

      aggregated = {}

      for category in @categories
        aggregated[category] = {}
        for district in GeoHierarchy.allDistricts()
          aggregated[category][district] = []

      for row in @positiveIndividualsByDiagnosisDate
        category = row.value[1]
        district = @districtForCase[row.value[0]]

        console.log row.value[0]
        console.log district

        unless district
          @$("#messages").append "Can't find district for <a href='#show/case/#{row.value[0]}'>#{row.value[0]}</a><br/>"
          continue

        aggregated[category][district].push row.value[0]

      @dropDownButton("District")

      @$("#classification").append @createTable ["District"].concat(@categories), "
        #{
          (for district in GeoHierarchy.allDistricts()
            "
            <tr>
							<td class='mdl-data-table__cell--non-numeric'>#{district}</td>
	
            #{
              (for category in @categories
                "
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(aggregated[category][district])}</td>
                "
              ).join("")
            }
            </tr>
            "
          ).join("")
        }
      ", "district-table"

      # This is for MDL switch
      componentHandler.upgradeAllRegistered()

 
  zone: =>
    aggregated = {}

    for category in @categories
      aggregated[category] = {}
      for zone in ["Unguja", "Pemba"]
        aggregated[category][zone] = []

    for row in @positiveIndividualsByDiagnosisDate
      category = row.value[1]
      zone = @zoneForCase[row.value[0]]

      console.log @zoneForCase
      console.log row.value[0]

      aggregated[category][zone].push row.value[0]

    @dropDownButton("Zone")

    @$("#classification").append @createTable ["Zone"].concat(@categories), "
      #{
        (for zone in ["Unguja","Pemba"]
          "
          <tr>
            <td class='mdl-data-table__cell--non-numeric'>#{zone}</td>

          #{
            (for category in @categories
              "
                <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(aggregated[category][zone])}</td>
              "
            ).join("")
          }
          </tr>
          "
        ).join("")
      }
    ", "zone-table"

    # This is for MDL switch
    componentHandler.upgradeAllRegistered()

  officer: => 
    aggregated = {}
    officers = []

    for category in @categories
      aggregated[category] = {}
      for caseId, officer of @officerForCase
        officers.push officer
        aggregated[category][officer] = []

    officers = _(officers).unique()

    for row in @positiveIndividualsByDiagnosisDate
      category = row.value[1]
      officer = @officerForCase[row.value[0]]

      aggregated[category][officer].push row.value[0]

    @dropDownButton("Officer")

    @$("#classification").append @createTable ["Officer"].concat(@categories), "
      #{
        (for officer in officers
          "
          <tr>
            <td class='mdl-data-table__cell--non-numeric'>#{officer}</td>

          #{
            (for category in @categories
              "
                <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(aggregated[category][officer])}</td>
              "
            ).join("")
          }
          </tr>
          "
        ).join("")
      }
    ", "officer-table"

    # This is for MDL switch
    componentHandler.upgradeAllRegistered()

  createDashboardLinkForResult: (malariaCase,resultType,buttonText, buttonClass = "") ->

    if malariaCase[resultType]?
      unless malariaCase[resultType].complete?
        unless malariaCase[resultType].complete
          buttonText = buttonText.replace(".png","Incomplete.png") unless resultType is "USSD Notification"
      HTMLHelpers.createCaseLink
        caseID: malariaCase.caseID
        docId: malariaCase[resultType]._id
        buttonClass: buttonClass
        buttonText: buttonText
    else ""

  createTable: (headerValues, rows, id, colspan = 1) ->
   "
      <div id='#{id}' class='analysis-report dropdown-section'>
      <div class='scroll-div'>
       <div style='font-style:italic; padding-right: 30px'>Click on a column heading to sort. <span class='toggle-btn f-right'></span> </div>
        <table #{if id? then "id=#{id}" else ""} class='tablesorter mdl-data-table mdl-js-data-table mdl-shadow--2dp'>
          <thead>
            <tr>
            #{
              _.map(headerValues, (header) ->
                "<th class='header mdl-data-table__cell--non-numeric' colspan='#{colspan}'>#{header}</th>"
              ).join("")
            }
            </tr>
          </thead>
          <tbody>
            #{rows}
          </tbody>
        </table>
       </div>
      </div>
    "

module.exports = IndividualClassificationView