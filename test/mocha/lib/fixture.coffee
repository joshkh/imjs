if process.env.IMJS_COV
  funcutils = require "../../../build-cov/util"
  {Service, Query, Model} = require '../../../build-cov/service'
else
  {Service, Query, Model} = require '../../../build/service'
  funcutils = require "../../../build/util"

args =
    root: process.env.TESTMODEL_URL ? 'localhost:8080/intermine-test'
    token: 'test-user-token'

console.log "Testing against #{ args.root }" if process.env.DEBUG

class Fixture

    constructor: ->
        @service = new Service args

        @allEmployees =
            select: ['*']
            from: 'Employee'

        @badQuery =
          select: ['name']
          from: 'Employee'
          where:
            id: 'foo'

        @olderEmployees =
            select: ['*']
            from: 'Employee'
            where:
                age:
                    gt: 50

        @youngerEmployees =
            select: ['*']
            from: 'Employee'
            where:
                age:
                    le: 50


Fixture.funcutils = funcutils
Fixture.Query = Query
Fixture.Model = Model
Fixture.Service = Service

module.exports = Fixture
