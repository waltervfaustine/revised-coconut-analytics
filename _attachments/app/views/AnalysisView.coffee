_ = require 'underscore'
$ = require 'jquery'
require('jquery-ui')
Backbone = require 'backbone'
Backbone.$  = $

global.jQuery = require 'jquery'
require 'tablesorter'
Tabulator = require 'tabulator-tables'
stripHtml = require("string-strip-html")

global.Reports = require '../models/Reports'
CaseView = require './CaseView'
SetsView = require './SetsView'
IndividualClassificationView = require './IndividualClassificationView'

class AnalysisView extends Backbone.View
  el: "#content"

  events:
    "click div.analysis.dropDownBtn": "showDropDown"
    "click #switch-details": "toggleDetails"
    "click #switch-unknown": "toggleGenderUnknown"
    "click button.caseBtn": "showCaseDialog"
    "click button#closeDialog": "closeDialog"
    "change [name=aggregationType]": "updateAnalysis"
    "click .download-csv": "downloadCSV"

  downloadCSV: (e) =>
    name = $(e.target).attr("data-tabulator-name")
    @tabulators[name].download("csv","#{name}_#{@startDate}_#{@endDate}.csv")

  toggleDetails: (e) =>
    @$(".details").toggle()

  toggleGenderUnknown: (e) =>
    @$('.gender-unknown').toggle()

  showDropDown: (e) =>
    target =  $(e.target).closest('.analysis')
    target.next(".analysis-report").slideToggle()
    target.find("i").toggleClass('mdi-play mdi-menu-down-outline')

    for name, tabulatorTable of @tabulators # tabulator doesn't initialize properly when hidden
      tabulatorTable.redraw()

  @showCaseDialog: (e) =>
    caseID = $(e.target).parent().attr('id') || $(e.target).attr('id')
    CaseView.showCaseDialog
      caseID: caseID
      success: ->
    return false

  closeDialog: () ->
    caseDialog.close() if caseDialog.open

  updateAnalysis: (e) =>
    Coconut.router.reportViewOptions.aggregationLevel = @$("[name=aggregationType]:checked").val()
    @render()

  render: =>
    $('#analysis-spinner').show()
    HTMLHelpers.ChangeTitle("Reports: Analysis")
    @$el.html "
      <style>
        td button.same-cell-disaggregatable{ float:right;}
        .mdl-data-table th { padding: 0 6px}

        .tabulator .tabulator-header .tabulator-col .tabulator-col-content .tabulator-col-title {
            white-space: normal;
        }

      </style>
      <dialog id='caseDialog'></dialog>
      <div id='dateSelector'></div>
      <div id='analysis'>
      <hr/>
      Aggregation Type:
      <input name='aggregationType' type='radio' #{if Coconut.router.reportViewOptions.aggregationLevel is "District" then "checked='true'" else ""} value='District'>&nbsp; District</input>
      <input name='aggregationType' type='radio' #{if Coconut.router.reportViewOptions.aggregationLevel is "Shehia" then "checked='true'" else ""}  value='Shehia'>&nbsp; Shehia</input>
      <div style='font-style:italic; margin-top: 10px'>Click on arrow button/title to show table.</div>
      <hr/>
      </div>
    "

    options = $.extend({},Coconut.router.reportViewOptions)

    @startDate = options.startDate
    @endDate = options.endDate

    Reports.casesAggregatedForAnalysis
      aggregationLevel:     options.aggregationLevel
      startDate:            options.startDate
      endDate:              options.endDate
      mostSpecificLocation: options.mostSpecificLocation
      error: (error) -> console.error error
      success: (data) =>
        $("#analysis-spinner").hide()
        caseInvestigationHeadings = [
          options.aggregationLevel
          "Cases for full investigation"
          "Cases investigated due to another case Investigation"
          "Fully Investigated"
          "%"
          "Complete facility visit"
          "Without complete record(but with case nofification)"
          "%"
          "Without complete facility visit within 24 hours"
          "%"
          "Without complete household visit (but with complete facility visit)"
          "%"
          "Without Full Investigation within 48 hours"
          "%"
        ]

        caseFollowUpHeadings = [
          options.aggregationLevel
          "Cases Notified (Improved)"
          "Cases Notified"
          "Case Notified Within 24hrs"
          "Accepted Cases"
          "Pending Accepted Nofification"
          "Multiple Notified"
          "False Positive"
          "Cases for Investigation"
          "Cases Lost to Follow-up"
          "Cases for Full Investigation"
          "Household with More Than One Case"
        ]

        individualClassificationHeadings = [
          options.aggregationLevel
          "With Travel History"
          "Imported"
          "Indigenous"
          "Introduced"
          "Induced"
          "Relapsing"
        ]

        $("#analysis").append "
		  <div class='analysis dropDownBtn'>
			  <div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i class='mdi mdi-play mdi-24px'></i></button>
		  Case Follow Up<small></small></div></div>
		"
        $("#analysis").append @createTable caseFollowUpHeadings, "
          #{
            _.map(data.followups, (values,location) =>
              # console.log "CAINAMIST::: ", JSON.stringify(values)
              # console.log "CAINAMIST::: ", JSON.stringify(location)
              "
                <tr>
                  <td class='mdl-data-table__cell--non-numeric'>#{location}</td>
                  # <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.allShoki)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.allCases)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.caseNotifiedWith24HRS)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.missingUssdNotification)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.missingCaseNotification)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.multipleNotified)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.falsePositive)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.casesForInvestigation)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ HTMLHelpers.createDisaggregatableCaseGroup(values.lostToFollowUp)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ HTMLHelpers.createDisaggregatableCaseGroup(values.casesForFullInvestigation)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ HTMLHelpers.createDisaggregatableCaseGroup(values.houseWithMoreThanOnePositiveCase)}</td>
                  
                </tr>
              "
            ).join("")
          }
        ", "cases-followed-up"

        $("#analysis").append "
		  <div class='analysis dropDownBtn'>
			  <div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i class='mdi mdi-play mdi-24px'></i></button>
		  Case Investigation<small></small></div></div>
		"
        $("#analysis").append @createTable caseInvestigationHeadings, "
          #{
            _.map(data.followups, (values,location) =>
              "
                <tr>
                  <td class='mdl-data-table__cell--non-numeric'>#{location}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.casesForFullInvestigation)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.casesInvestigatedDueToAnotherCaseInvestigation)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.casesWithCompleteHouseholdVisit)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.formattedPercent(values.casesWithCompleteHouseholdVisit.length/values.casesForFullInvestigation.length)}</td>
                  <td class='details mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.casesWithCompleteFacilityVisit)}</td>
                  #{
                    withoutcompletefacilityvisitbutwithcasenotification = _.difference(values.casesWithoutCompleteFacilityVisit,values.missingCaseNotification)
                    ""
                  }
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(withoutcompletefacilityvisitbutwithcasenotification)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.formattedPercent(withoutcompletefacilityvisitbutwithcasenotification.length/values.casesForFullInvestigation.length)}</td>

                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.noFacilityFollowupWithin24Hours)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.formattedPercent(values.noFacilityFollowupWithin24Hours.length/values.casesForFullInvestigation.length)}</td>


                  #{
                    withoutcompletehouseholdvisitbutwithcompletefacility = _.difference(values.casesWithoutCompleteHouseholdVisit,values.casesWithCompleteFacilityVisit)
                    ""
                  }

                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(withoutcompletehouseholdvisitbutwithcompletefacility)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.formattedPercent(withoutcompletehouseholdvisitbutwithcompletefacility.length/values.casesForFullInvestigation.length)}</td>


                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.noHouseholdFollowupWithin48Hours)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.formattedPercent(values.noHouseholdFollowupWithin48Hours.length/values.casesForFullInvestigation.length)}</td>

                </tr>
              "
            ).join("")
          }
        ", "case-investigation"

        _([
          "Complete facility visit"
          "Missing Sent Case Notification"
        ]).each (column) ->
          $("th:contains(#{column})").addClass "details"
        $(".details").hide()


        _.delay ->

          $("table.tablesorter").each (index,table) ->

            _($(table).find("tr:nth-child(1) td").length).times (columnNumber) ->
            #_($(table).find("th").length).times (columnNumber) ->
              return if columnNumber is 0

              maxIndex = null
              maxValue = 0
              columnsTds = $(table).find("td:nth-child(#{columnNumber+1})")
              columnsTds.each (index,td) ->
                return if index is 0
                td = $(td)
                value = parseInt(td.text())
                if value > maxValue
                  maxValue = value
                  maxIndex = index
              $(columnsTds[maxIndex]).addClass "max-value-for-column" if maxIndex
          $(".max-value-for-column ").css("color","#FF4081")
          $(".max-value-for-column ").css("font-weight","bold")
          $(".max-value-for-column button.same-cell-disaggregatable").css("color","#FF4081")

        ,2000

        $("div#case-investigation span.toggle-btn").html "
          <label class='mdl-switch mdl-js-switch mdl-js-ripple-effect' for='switch-details'>
            <input type='checkbox' id='switch-details' class='mdl-switch__input'>
            <span class='mdl-switch__label'>Toggle Details</span>
          </label>
        "
        $("#analysis").append "
          </div>
          <hr>
		  <div class='analysis dropDownBtn'>
		  	<div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i  class='mdi mdi-play mdi-24px'></i></button>
            Index Household and Neighbors</div>
		  </div>
        "


        @createTabulator "index-house-neighbors", (for location, values of data.passiveCases
          "#{options.aggregationLevel}": location
          "Fully investigated": HTMLHelpers.createDisaggregatableCaseGroup(values.indexCases)
          "No of additional index household members tested": HTMLHelpers.createDisaggregatableDocGroup(values.indexCaseHouseholdMembers.length,values.indexCaseHouseholdMembers)
          "No of additional index household members tested positive": HTMLHelpers.createDisaggregatableDocGroup(values.positiveIndividualsAtIndexHousehold.length,values.positiveIndividualsAtIndexHousehold)
          "% of index household members tested positive": HTMLHelpers.formattedPercent(values.positiveIndividualsAtIndexHousehold.length / values.indexCaseHouseholdMembers.length)
          "% increase in cases found using MCN": HTMLHelpers.formattedPercent(values.positiveIndividualsAtIndexHousehold.length / values.indexCases.length)
          "No of additional neighbor households visited": HTMLHelpers.createDisaggregatableDocGroup(values.neighborHouseholds.length,values.neighborHouseholds)
          "No of additional neighbor household members tested": HTMLHelpers.createDisaggregatableDocGroup(values.neighborHouseholdMembers.length,values.neighborHouseholdMembers)
          "No of additional neighbor household members tested positive": HTMLHelpers.createDisaggregatableDocGroup(values.positiveIndividualsAtNeighborHouseholds.length,values.positiveIndividualsAtNeighborHouseholds)
        )

        $("#analysis").append "
		  <div class='analysis dropDownBtn'>
			  <div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i class='mdi mdi-play mdi-24px'></i></button>
		  Individual Classification<small></small></div></div>
		"
        $("#analysis").append @createTable individualClassificationHeadings, "
          #{
            _.map(data.individualClassification, (values,location) =>
              "
                <tr>
                  <td class='mdl-data-table__cell--non-numeric'>#{location}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.withTravelHistory)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.imported)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.indigenous)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.introduced)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.induced)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableCaseGroup(values.relapsing)}</td>
                  
                </tr>
              "
            ).join("")
          }
        ", "individual-classifications"


        $("#analysis").append "

          <hr>
          <div class='analysis dropDownBtn'>
            <div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i class='mdi mdi-play mdi-24px'></i></button>
		  		Age: <small>Includes index cases with complete household visits, positive index case household members, and positive neighbor household members</small></div>
          </div>
        "
        $("#analysis").append @createTable "#{options.aggregationLevel}, Total, <5, %, 5<15, %, 15<25, %, >=25, %, Unknown, %".split(/, */), "
          #{
            _.map(data.ages, (values,location) =>
              "
                <tr>
                  <td class='mdl-data-table__cell--non-numeric'>#{location}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.underFive.length,values.underFive)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.underFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.fiveToFifteen.length,values.fiveToFifteen)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.fiveToFifteen.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.fifteenToTwentyFive.length,values.fifteenToTwentyFive)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.fifteenToTwentyFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.overTwentyFive.length,values.overTwentyFive)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.overTwentyFive.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.unknown.length,values.unknown)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.unknown.length / data.totalPositiveCases[location].length)}</td>

                </tr>
              "
            ).join("")
          }
        ", 'age'

        $("#analysis").append "
		  </div>
          <hr>
		  <div class='analysis dropDownBtn'>
		  	<div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i class='mdi mdi-play mdi-24px'></i></button>
		  		Gender: <small>Includes index cases with complete household visits, positive index case household members, and positive neighbor household members</small>
		  	</div>
		  </div>
        "
        $("#analysis").append @createTable "#{options.aggregationLevel}, Total, Male, %, Female, %, Unknown, %".split(/, */), "
          #{
            _.map(data.gender, (values,location) =>
              "
                <tr>
                  <td class='mdl-data-table__cell--non-numeric'>#{location}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.male.length,values.male)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.male.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.female.length,values.female)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.female.length / data.totalPositiveCases[location].length)}</td>
                  <td style='display:none' class='gender-unknown'>#{HTMLHelpers.createDisaggregatableDocGroup(values.unknown.length,values.unknown)}</td>

                  <td style='display:none' class='gender-unknown'>#{HTMLHelpers.formattedPercent(values.unknown.length / data.totalPositiveCases[location].length)}</td>
                </tr>
              "
            ).join("")
          }
        ", "gender"
        $("table#gender th:nth-child(7)").addClass("gender-unknown").css("display", "none")
        $("table#gender th:nth-child(8)").addClass("gender-unknown").css("display", "none")

        $("div#gender span.toggle-btn").html "
          <label class='mdl-switch mdl-js-switch mdl-js-ripple-effect' for='switch-unknown'>
            <input type='checkbox' id='switch-unknown' class='mdl-switch__input'>
            <span class='mdl-switch__label'>Toggle Unknown</span>
          </label>
        "
        
        $("#analysis").append "
          </div>
          <hr>
		  <div class='analysis dropDownBtn'>
		  	<div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i class='mdi mdi-play mdi-24px'></i></button>
		  		Nets and Spraying: <small>Includes index cases with complete household visits, positive index case household members, and positive neighbor household members</small>
		  	</div>
		  </div>
        "
    
        $("#analysis").append @createTable "#{options.aggregationLevel}, Positive Cases (index & household), Slept under a net night before diagnosis, %, Household has been sprayed within last #{Coconut.IRSThresholdInMonths} months, %".split(/, */), "
    
          #{
            _.map(data.netsAndIRS, (values,location) =>
              "
                <tr>
                  <td class='mdl-data-table__cell--non-numeric'>#{location}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(data.totalPositiveCases[location].length,data.totalPositiveCases[location])}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.sleptUnderNet.length,values.sleptUnderNet)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.sleptUnderNet.length / data.totalPositiveCases[location].length)}</td>
                  <td>#{HTMLHelpers.createDisaggregatableDocGroup(values.recentIRS.length,values.recentIRS)}</td>
                  <td>#{HTMLHelpers.formattedPercent(values.recentIRS.length / data.totalPositiveCases[location].length)}</td>
                </tr>
              "
            ).join("")
          }
        ", 'nets-and-spraying'

        $("#analysis table").tablesorter
          widgets: ['zebra']
          sortList: [[0,0]]
          textExtraction: (node) ->
           sortValue = $(node).find(".sort-value").text()
           if sortValue != ""
              sortValue
            else
              if $(node).text() is "--"
                "-1"
              else
                $(node).text()

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

  createTabulator: (id, data) =>
    @$("#analysis").append "
      <div class='analysis-report dropdown-section'>
        <button class='download-csv' data-tabulator-name='#{id}'>Download CSV</button>
        <div id='#{id}'/>
      </div>
    "

    @tabulators or= {}
    @tabulators[id] = new Tabulator "##{id}",
      layout: "fitColumns"
      columns: for columnName in Object.keys(data[0])
        title: columnName
        field: columnName
        sorter: "number"
        formatter: "html"
        accessorDownload: (value) =>
          # Just show the aggregated value in the CSV
          value = stripHtml(value) # remove html
          if match = value.match(/(\d+) +\d+/) # remove disaggregated cases
            match[1]
          else
            value

      data: data

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

module.exports = AnalysisView
