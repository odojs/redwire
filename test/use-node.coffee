expect = require('chai').expect
UseNode = require '../src/use-node'

describe 'Use Node', ->
  it 'should exec with no nodes', ->
    node = new UseNode()
    node.exec ->
  
  it 'should exec with no args', ->
    node = new UseNode()
    failed = yes
    node.use (next) ->
      failed = no
      next()
    node.exec ->
    expect(failed).to.be.false()
  
  it 'should exec with args', ->
    node = new UseNode()
    failed = yes
    node.use (arg, next) ->
      failed = no
      expect(arg).to.be.eql 'yup'
      next()
    node.exec 'yup', ->
    expect(failed).to.be.false()
  
  it 'should cascade', ->
    node = new UseNode()
    failed1 = yes
    node.use (arg, next) ->
      failed1 = no
      expect(arg).to.be.eql 'yup'
      next()
    failed2 = yes
    node.use (arg, next) ->
      failed2 = no
      expect(arg).to.be.eql 'yup'
      next()
    node.exec 'yup', ->
    expect(failed1).to.be.false()
    expect(failed2).to.be.false()