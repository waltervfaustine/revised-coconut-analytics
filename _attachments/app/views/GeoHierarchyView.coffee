_ = require 'underscore'
$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $
moment = require 'moment'
require 'tablesorter'
Dialog = require './Dialog'
humanize = require 'underscore.string/humanize'
Form2js = require 'form2js'
js2form = require 'form2js'

Tabulator = require 'tabulator-tables'

class GeoHierarchyView extends Backbone.View
  el: '#content'

  events:
    "click #updateFromDhis": "updateFromDhis"
    "click #download": "csv"
    "click #new-district-btn": "createDistrict"
    "click #new-shehia-btn": "createShehia"
    "click #new-facility-btn": "createFacility"
    "click .addAlias": "addAlias"
    "click button#ghSave": "addGeoLocation"
    "click button#ghCancel": "formCancel"
    "click button#buttonYes": "deleteGeo"

  createDistrict: (e) =>
    e.preventDefault
    @mode = 'district'
    dialogTitle = "Add New District"
    Dialog.create(@dialogDistrict, dialogTitle)
    $('form#district input').val('')
    return false

  createShehia: (e) =>
    e.preventDefault
    @mode = 'shehia'
    dialogTitle = "Add New Shehia"
    Dialog.create(@dialogShehia, dialogTitle)
    $('form#shehia input').val('')
    return false

  createFacility: (e) =>
    e.preventDefault
    @mode = 'facility'
    dialogTitle = "Add New Facility"
    Dialog.create(@dialogFacility, dialogTitle)
    $('form#facility input').val('')
    return false

  addAlias: (event) =>
    targetForAlias = $(event.target).attr("data-name")
    newAlias = prompt "What is the new alias for #{targetForAlias}?"
    if targetForAlias? and newAlias?
      await GeoHierarchy.addAlias(targetForAlias, newAlias)
      document.location.reload()

  addGeoLocation: (event) =>
    @data = {}
    @data.Region = $("input#Region").val()
    @data.District = $("input#District").val()
    @data.Shehia = $("input#Shehia").val()
    @data.Facility = $("input#Facility").val()

    err = undefined
    if @mode is "district"
      parent = @data.Region
      child = @data.District
      if @data.Region? and @data.District?
        err = await GeoHierarchy.addDistrict(@data.Region, @data.District)
    else if @mode is "shehia"
      parent = @data.District
      child = @data.Shehia
      if @data.Shehia? and @data.District?
        err = await GeoHierarchy.addShehia(@data.District, @data.Shehia) 
    else if @mode is "facility"
      parent = @data.Shehia
      child = @data.Facility
      if @data.Shehia? and @data.Facility?
        err = await GeoHierarchy.addFacility(@data.Shehia, @data.Facility)

    if err
      alert "Failed to add #{child} to #{parent}: #{err}"
    else
      dialog.close() if dialog.open
      document.location.reload()

    return false

  csv: => @tabulator.download "csv", "CoconutTableExport.csv"

  render: =>
    options = $.extend({},Coconut.router.reportViewOptions)
    @mode = "facility"
    @document_id = "Geo Hierarchy"
    @dialogDistrict = "
      <form id='district' method='dialog'>
        <div id='dialog-title'> </div>
        <div class='mdl-textfield mdl-js-textfield mdl-textfield--floating-label'>
          <input class='mdl-textfield__input' type='text' id='Region' name='Region'></input>
          <label class='mdl-textfield__label'>Region</label>
        </div>
        <div class='mdl-textfield mdl-js-textfield mdl-textfield--floating-label'>
          <input class='mdl-textfield__input' type='text' id='District' name='District'></input>
          <label class='mdl-textfield__label'>District</label>
        </div>                        
        <div id='dialogActions'>
           <button class='mdl-button mdl-js-button mdl-button--primary' id='ghSave' type='submit' value='save'><i class='mdi mdi-content-save mdi-24px'></i> Save</button> &nbsp;
           <button class='mdl-button mdl-js-button mdl-button--primary' id='ghCancel' type='submit' value='cancel'><i class='mdi mdi-close-circle mdi-24px'></i> Cancel</button>
        </div>
      </form>
    "
    @dialogShehia = "
      <form id='shehia' method='dialog'>
        <div id='dialog-title'> </div>
        <div class='mdl-textfield mdl-js-textfield mdl-textfield--floating-label'>
          <input class='mdl-textfield__input' type='text' id='District' name='District'></input>
          <label class='mdl-textfield__label'>District</label>
        </div>  
        <div class='mdl-textfield mdl-js-textfield mdl-textfield--floating-label'>
          <input class='mdl-textfield__input' type='text' id='Shehia' name='Shehia'></input>
          <label class='mdl-textfield__label'>Shehia</label>
        </div>                      
        <div id='dialogActions'>
           <button class='mdl-button mdl-js-button mdl-button--primary' id='ghSave' type='submit' value='save'><i class='mdi mdi-content-save mdi-24px'></i> Save</button> &nbsp;
           <button class='mdl-button mdl-js-button mdl-button--primary' id='ghCancel' type='submit' value='cancel'><i class='mdi mdi-close-circle mdi-24px'></i> Cancel</button>
        </div>
      </form>
    "
    @dialogFacility = "
      <form id='facility' method='dialog'>
        <div id='dialog-title'> </div>
        <div class='mdl-textfield mdl-js-textfield mdl-textfield--floating-label'>
          <input class='mdl-textfield__input' type='text' id='Shehia' name='Shehia'></input>
          <label class='mdl-textfield__label'>Shehia</label>
        </div>
        <div class='mdl-textfield mdl-js-textfield mdl-textfield--floating-label'>
          <input class='mdl-textfield__input' type='text' id='Facility' name='Facility'></input>
          <label class='mdl-textfield__label'>Facility</label>
        </div>                        
        <div id='dialogActions'>
           <button class='mdl-button mdl-js-button mdl-button--primary' id='ghSave' type='submit' value='save'><i class='mdi mdi-content-save mdi-24px'></i> Save</button> &nbsp;
           <button class='mdl-button mdl-js-button mdl-button--primary' id='ghCancel' type='submit' value='cancel'><i class='mdi mdi-close-circle mdi-24px'></i> Cancel</button>
        </div>
      </form>
    "
    @$el.html "
      <h2>Regions, Districts, Facilities and Shehias</h2>
      <button class='' id='new-district-btn'>Add District</button>
      <button class='' id='new-shehia-btn'>Add Shehia</button>
      <button class='' id='new-facility-btn'>Add Health Facility</button>
      <dialog id='dialog'>
        <div id='dialogContent'> </div>
      </dialog>
      <br/>
      <br/>
      <button id='download'>CSV ↓</button>
      <div id='tabulator'></div>
    "

    @tabulator = new Tabulator "#tabulator",
      height: 500
      columns: for field in [
        "Name"
        "Level"
        "One level up"
        "Two levels up"
        "Aliases"
        "Actions"
      ]
        result = {
          title: field
          field: field
          headerFilter: "input" unless field is "Actions"
        }
        switch field
          when "Name"
            result["formatterParams"] = urlField: "url"
            result["formatter"] = "link"
          when "Actions"
            result["formatter"] = (cell, formatterParams, onRendered) ->
              "<button class='addAlias' data-name='#{cell.getRow().getData().Name}'>Add Alias</button>"

        result

      data: for unit in GeoHierarchy.units
        {
          Name: unit.name
          Level: unit.levelName
          "One level up": "#{unit.parent()?.levelName or ""}: #{unit.parent()?.name or ""}"
          "Two levels up": "#{unit.parent()?.parent()?.levelName or ""}: #{unit.parent()?.parent()?.name or ""}"
          url: "#dashboard/administrativeLevel/#{unit.levelName}/administrativeName/#{unit.name}"
          "Aliases": if (alias = GeoHierarchy.externalAliases[unit.name]) then alias else ""
        }

  formCancel: (e) =>
    e.preventDefault
    console.log("Cancel pressed")
    dialog.close() if dialog.open
    return false

module.exports = GeoHierarchyView
