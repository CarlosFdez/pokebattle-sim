{Attachments, Attachment} = require '../server/attachment'
should = require 'should'

describe "An Attachment list", ->
  class TestAttachment extends Attachment
    name: "TestAttachment"
    maxLayers: 2

  class OtherAttachment extends Attachment
    name: "OtherAttachment"

  beforeEach ->
    @attachments = new Attachments()

  it "will not add attachments past the maximum stack", ->
    should.exist @attachments.push(TestAttachment)
    should.exist @attachments.push(TestAttachment)
    should.not.exist @attachments.push(TestAttachment)

  describe '#unattach', ->
    it "removes the current attachment", ->
      @attachments.push(TestAttachment)
      @attachments.unattach(TestAttachment)
      @attachments.attachments.should.have.length(0)

    it "does not remove other attachments if none is found", ->
      @attachments.push(TestAttachment)
      @attachments.unattach(OtherAttachment)
      @attachments.attachments.should.have.length(1)
      @attachments.attachments[0].should.be.instanceOf(TestAttachment)

  describe '#getPassable', ->
    beforeEach ->
      @attachments.push(Attachment.Embargo)
      @attachments.push(Attachment.Yawn)
      @attachments.push(Attachment.Ingrain)
      @attachments.push(Attachment.AquaRing)
      @attachments.push(Attachment.AirBalloon)
      @attachments.push(Attachment.Disable)
      @attachments.push(Attachment.Torment)
      @attachments.push(Attachment.Substitute)
      @attachments.push(Attachment.Curse)
      @attachments.push(Attachment.LeechSeed)
      @attachments.push(Attachment.MagnetRise)
      @attachments.push(Attachment.LockOn)
      @attachments.push(Attachment.Confusion)

    it "returns an array of passable attachments already attached", ->
      attachments = @attachments.getPassable()
      attachments.should.not.include(Attachment.Disable)
      attachments.should.not.include(Attachment.Torment)
      attachments.should.not.include(Attachment.Yawn)
      attachments.should.not.include(Attachment.AirBalloon)
      attachments.should.include(Attachment.Ingrain)
      attachments.should.include(Attachment.AquaRing)
      attachments.should.include(Attachment.Embargo)
      attachments.should.include(Attachment.Substitute)
      attachments.should.include(Attachment.Curse)
      attachments.should.include(Attachment.LeechSeed)
      attachments.should.include(Attachment.LockOn)
