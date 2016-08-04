Fixture                = require './lib/fixture'
{prepare, eventually, shouldFail}  = require './lib/utils'
{invokeWith, invoke, defer, get, flatMap} = Fixture.funcutils
should = require 'should'

ROWS = 87
ROW = "10\tEmployeeA1"
SUM = 2688
SLOW = 100

toRows = (text) -> text.split /\n/

describe 'TSV results', ->

  rowresults = 0

  @slow SLOW
  {service, youngerEmployees} = new Fixture()

  query =
    select: ['age', 'name']
    from: 'Employee'
    where: youngerEmployees.where

  @beforeAll ->
    service.query(query)
           .then (q) -> service.post 'query/results', format: 'tsv', query: q.toXML()
         .then toRows
         .then (r) -> rowresults = r

  describe '#post(path, format: "tsv")', ->

    it "should return #{ ROWS } rows", ->
      rowresults.length.should.eql ROWS

    it 'should return things that look like tab separated values', ->
      should.exist rowresults
      rowresults[0].should.equal ROW
