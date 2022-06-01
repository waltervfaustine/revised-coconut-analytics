global.PouchDB = require 'pouchdb-browser'
PouchDB.plugin(require('pouchdb-upsert'))
BackbonePouch = require 'backbone-pouch'
global.Cookie = require 'js-cookie'
global.Config = require '../config.json'
moment = require 'moment'

class Coconut

  currentlogin: Cookies.get('current_user') || null

  reportDates:
    startDate: moment().subtract("7","days").format("YYYY-MM-DD")
    endDate: moment().format("YYYY-MM-DD")

  setupDatabases: =>
    username = Cookie.get("username") or Config.username or prompt("Username:")
    password = Cookie.get("password") or Config.password or prompt("Password:")

    Cookie.set("username", username)
    Cookie.set("password", password)

    databaseOptions = {ajax: timeout: 1000 * 60 * 10} # Ten minutes

    @databaseURL =
      if window.location.origin.startsWith "http://localhost"
        "http://#{username}:#{password}@localhost:5984/"
      else if Config.targetUrl
        "https://#{username}:#{password}@#{Config.targetUrl}/"
      else 
        prompt("Database URL:")

    @databaseName = Config.targetDatabase or prompt("Database Name:")
    @database = new PouchDB("#{@databaseURL}/#{@databaseName}", databaseOptions)
    @reportingDatabase = new PouchDB("#{@databaseURL}/zanzibar-reporting", databaseOptions)
    @cachingDatabase = new PouchDB("coconut-zanzibar-caching")
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
