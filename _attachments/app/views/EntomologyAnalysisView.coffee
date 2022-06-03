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

class EntomologyAnalysisView extends Backbone.View
  el: "#content"

  events:
    "click div.entomology.dropDownBtn": "showDropDown"
    "click #switch-details": "toggleDetails"
    "click #switch-unknown": "toggleGenderUnknown"
    "click button.caseBtn": "showCaseDialog"
    "click button#closeDialog": "closeDialog"
    "change [name=aggregationLevel]": "updateAnalysis"
    "click .download-csv": "downloadCSV"

  showDropDown: (e) =>
    target =  $(e.target).closest('.entomology')
    target.next(".entomology-report").slideToggle()
    target.find("i").toggleClass('mdi-play mdi-menu-down-outline')

    for name, tabulatorTable of @tabulators # tabulator doesn't initialize properly when hidden
      tabulatorTable.redraw()
  updateAnalysis: (e) =>
    Coconut.router.entomologyViewOptions.aggregationLevel = @$("[name=aggregationLevel]:checked").val()
    @render()
    
  render: =>
    HTMLHelpers.ChangeTitle("Reports: Entomology")
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
      <div id='entomology'>
      <hr/>
      Aggregation Type:
      <input name='aggregationLevel' type='radio' #{if Coconut.router.entomologyViewOptions.aggregationLevel is "District" then "checked='true'" else ""} value='District'>&nbsp; District</input>
      <input name='aggregationLevel' type='radio' #{if Coconut.router.entomologyViewOptions.aggregationLevel is "Shehia" then "checked='true'" else ""}  value='Shehia'>&nbsp; Shehia</input>
      <div style='font-style:italic; margin-top: 10px'>Click on arrow button/title to show table.</div>
      <hr/>
      </div>
    "
    options = $.extend({},Coconut.router.entomologyViewOptions)

    @startDate = options.startDate
    @endDate = options.endDate

    Reports.specimensAggregatedForAnalysis
      aggregationLevel:     options.aggregationLevel
      startDate:            options.startDate
      endDate:              options.endDate
      mostSpecificLocation: options.mostSpecificLocation
      error: (error) -> console.error error
      success: (data) =>
        identificationAndAbundanceHeadings = [
          options.aggregationLevel
          "An gambiae complex"
          "% An gambiae complex"
          "An funestus"
          "% An funestus"
          "An costani"
          "% An costani"
          "An maculipalpis"
          "% An maculipalpis"
          "An nili"
          "% An nili"
          "Other species"
          "% Other species"
          "Total"
        ]
        vectorsPerMethodPerSiteHeadings = [
          options.aggregationLevel
          "Human Landing Catch An gambiae s.l(n)"
          "Human Landing Catch An funestus s.l(n)"
          "Pyrethrum Spray Catch An gambiae s.l(n)"
          "Pyrethrum Spray Catch An funestus s.l(n)"
          "CDC Light Trap An gambiae s.l(n)"
          "CDC Light Trap An funestus s.l(n)"
          "Pit Trap An gambiae s.l(n)"
          "Pit Trap An funestus s.l(n)"
          "Total An gambiae s.l(n)"
          "Total An funestus s.l(n)"
        ]

        $("#entomology").append "
        <div class='entomology dropDownBtn'>
          <div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i class='mdi mdi-play mdi-24px'></i></button>
          Malaria vector abundance, Morphological identification and distribution<small></small></div></div>
      "
        $("#entomology").append @createTable identificationAndAbundanceHeadings, "
          #{
            _.map(data.identificationAndAbundance, (values,location) =>
              totalCount = values.allVectors?.length
              if(values.allVectors?.length < 1)
                values.allVectors?.length = 1
              "
                <tr>
                  <td class='mdl-data-table__cell--non-numeric'>#{location}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{values.anGambiaeComplex?.length}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{(values.anGambiaeComplex?.length/values.allVectors?.length)*100}%</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{values.anFunestus?.length}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{(values.anFunestus?.length/values.allVectors?.length)*100}%</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{values.anCostani?.length}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{(values.anCostani?.length/values.allVectors?.length)*100}%</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{values.anMaculipalpis?.length}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{(values.anMaculipalpis?.length/values.allVectors?.length)*100}%</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{values.anNili?.length}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{(values.anNili?.length/values.allVectors?.length)*100}%</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ values.otherSpecies?.length}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{(values.otherSpecies?.length/values.allVectors?.length)*100}%</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ totalCount}</td>
                  
                </tr>
              "
            ).join("")
          }
        ", "identification-and-abundance"
        

        $("#entomology").append "
        <div class='entomology dropDownBtn'>
          <div class='report-subtitle'><button class='mdl-button mdl-js-button mdl-button--icon'><i class='mdi mdi-play mdi-24px'></i></button>
          Number of vectors collected per method per site ignore sprayed and unsprayed<small></small></div></div>
      "
        $("#entomology").append @createTable vectorsPerMethodPerSiteHeadings, "
          #{
            _.map(data.vectorsPerMethodPerSite, (values,location) =>
              totalAnGambiae = values.humanLandingCatchAnGambiae?.length+values.pyrethrumSprayCatchAnGambiae?.length+values.pitTrapAnGambiae?.length+ values.cdcLightTrapAnGambiae?.length
              totalAnFunestus = values.humanLandingCatchAnFunestus?.length+values.pyrethrumSprayCatchAnFunestus?.length+values.pitTrapAnFunestus?.length+ values.cdcLightTrapAnFunestus?.length
              "
                <tr>
                  <td class='mdl-data-table__cell--non-numeric'>#{location}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableSpecimenGroup(values.humanLandingCatchAnGambiae)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableSpecimenGroup(values.humanLandingCatchAnFunestus)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableSpecimenGroup(values.pyrethrumSprayCatchAnGambiae)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableSpecimenGroup(values.pyrethrumSprayCatchAnFunestus)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{HTMLHelpers.createDisaggregatableSpecimenGroup(values.pitTrapAnGambiae)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ HTMLHelpers.createDisaggregatableSpecimenGroup(values.pitTrapAnFunestus)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ HTMLHelpers.createDisaggregatableSpecimenGroup(values.cdcLightTrapAnGambiae)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ HTMLHelpers.createDisaggregatableSpecimenGroup(values.cdcLightTrapAnFunestus)}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ totalAnGambiae}</td>
                  <td class='mdl-data-table__cell--non-numeric'>#{ totalAnFunestus}</td>
                </tr>
              "
            ).join("")
          }
        ", "vectors-per-method-per-site"

        $("#entomology table").tablesorter
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
    console.log data
    @$("#entomology").append "
      <div class='entomology-report dropdown-section'>
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
      <div id='#{id}' class='entomology-report dropdown-section'>
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
module.exports = EntomologyAnalysisView
