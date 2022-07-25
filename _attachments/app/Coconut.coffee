global.PouchDB = require 'pouchdb-browser'
PouchDB.plugin(require('pouchdb-upsert'))
BackbonePouch = require 'backbone-pouch'
global.Cookie = require 'js-cookie'
AppConfig = require '../config.json'
moment = require 'moment'

class Coconut

  currentlogin: Cookies.get('current_user') || null

  reportDates:
    startDate: moment().subtract("7","days").format("YYYY-MM-DD")
    endDate: moment().format("YYYY-MM-DD")

  setupDatabases: =>
    username = AppConfig.username or prompt("Username:")
    password = AppConfig.password or prompt("Password:")

    databaseOptions = {ajax: timeout: 1000 * 60 * 10} # Ten minutes

    @databaseURL =
      if window.location.origin.startsWith "http://localhost"
        "http://#{username}:#{password}@localhost:5984/"
      else if AppConfig.targetUrl
        "https://#{username}:#{password}@#{AppConfig.targetUrl}/"
      else 
        prompt("Database URL:")

    @databaseName = AppConfig.targetDatabase or prompt("Database Name:")
    @database = new PouchDB("#{@databaseURL}/#{@databaseName}", databaseOptions)
    @reportingDatabase = new PouchDB("#{@databaseURL}/zanzibar-reporting", databaseOptions)
    @cachingDatabase = new PouchDB("coconut-zanzibar-caching")
    @zanzibarGeoPluginDatabase = new PouchDB("#{@databaseURL}/plugin-zanzibar-geography")
    @weeklyFacilityDatabase = new PouchDB("#{@databaseURL}/zanzibar-weekly-facility")
    @individualIndexDatabase = new PouchDB("#{@databaseURL}/zanzibar-index-individual")
    @entomologyDatabase = new PouchDB("#{@databaseURL}/entomology_surveillance")

  promptUntilCredentialsWork: =>
    @setupDatabases()
    @database.info()
    .catch (error) =>
      alert("Invalid username or password")
      Cookie.remove("username")
      Cookie.remove("password")
      @promptUntilCredentialsWork()

module.exports = Coconut
