_ = require 'underscore'
$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $

Reports = require '../models/Reports'
moment = require 'moment'
dc = require 'dc'
d3 = require 'd3'
crossfilter = require 'crossfilter'

class IncidentsGraphView extends Backbone.View
  el: "#content"

  render: =>
    options = $.extend({},Coconut.router.reportViewOptions)
    @$el.html "
       <style>
         .chart_container {height: 600px}
       </style>
       <div id='dateSelector'></div>
       <div class='chart-title'>Number of Cases</div>
       <div id='chart_container_1' class='chart_container'>
         <div class='mdl-grid'>
           <div class='mdl-cell mdl-cell--12-col mdl-cell--8-col-tablet mdl-cell--4-col-phone'>
             <div id='chart'></div>
           </div>
         </div>
       </div>
    "
    
    $('#analysis-spinner').show()
    adjustX = 10
    adjustY = 40
    container = 'chart_container_1'
    options.y_axis = 'y_axis_1'
    options.x_axis = 'x_axis_1'
    options.chart = 'chart_1'
    options.renderer = 'bar'
    options.names = ["Age < 5","Age >= 5"]
    chart_width = $('.chart_container').width()-adjustX
    chart_height = $('.chart_container').width()-adjustY
    couch_view1 = "positiveCases"
    container = 'chart_container_1'
    startDate = moment(options.startDate).format('YYYY-MM-DD')
    endDate = moment(options.endDate).format('YYYY-MM-DD')
    Coconut.database.query "#{couch_view1}/#{couch_view1}",
      startkey: startDate
      endkey: endDate
      include_docs: true
    .then (result) =>
      data1ForGraph = _.pluck(result.rows, 'doc')
      if (data1ForGraph.length == 0 or _.isEmpty(data1ForGraph[0]))
         $("div##{container}").html("<center><div style='margin-top: 5%'><h6>No records found for date range</h6></div></center>")
         #reject("No record for date range")
         $('#analysis-spinner').hide()
      else
        data1ForGraph.forEach((d) ->
          d.datePR = new Date(d.DateofPositiveResults)
        )
        chart = dc.lineChart("#chart")
        ndx = crossfilter(data1ForGraph)
        
        dim = ndx.dimension((d) ->
          return d.datePR
        )

        grp = dim.group()

        chart
          .width($('.chart_container').width()-adjustX)
          .height($('.chart_container').height()-adjustY)
          .x(d3.time.scale().domain([new Date(options.startDate), new Date(options.endDate)]))
          .y(d3.scale.linear().domain([0,120]))
          .yAxisLabel("Number of Incidents")
          .elasticY(true)
          .renderHorizontalGridLines(true)
          .dimension(dim)
          .colors('red')
          .group(grp)
          # .dashStyle([2,2])
          .xyTipsOn(true)
          .renderDataPoints(false)
          .title((d) ->
            return d.key.toDateString() + ": " + d.value
          )
          .brushOn(false)

        chart.render()

        window.onresize = () ->
          chart
            .width($('.chart_container').width()-adjustX)
            .height($('.chart_container').height()-adjustY)
            .rescale()
            .redraw();
                  
        $('#analysis-spinner').hide()
    .catch (error) ->
      console.error error
      $('#analysis-spinner').hide()
    
module.exports = IncidentsGraphView
