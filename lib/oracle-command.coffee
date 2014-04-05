spawn = require('child_process').spawn
{Subscriber, Emitter} = require 'emissary'

module.exports =
class OracleCommand
  Subscriber.includeInto(this)
  Emitter.includeInto(this)

  oracleCommand: (cmd, format, importPath) ->
    path = @getPath()
    [startOffset, endOffset] = @getPosition()

    gopath = @goPath()
    env = {"GOPATH": gopath}
    oracleCmd = atom.config.get('go-oracle.oraclePath')
    oracleCmd = oracleCmd.replace(/^\$GOPATH\//i, gopath)

    args = ["-pos=#{path}:##{startOffset}", "-format=#{format}", cmd]
    args.push(importPath) if importPath?

    console.log "#{oracleCmd} -pos=#{path}:##{startOffset} -format=plain #{cmd} #{importPath}"

    return spawn(oracleCmd, args, {"env": env})

  constructor: ->
    this.on 'what-complete', (importPath) =>
      cmd = @oracleCommand(@nextCommand, "plain", importPath)
      parsedData = ''
      cmd.stdout.on 'data', (data) =>
        parsedData = data

      cmd.on 'close', (code) =>
        @emit "oracle-complete", @nextCommand, parsedData

  what: ->
    what = @oracleCommand("what", "json")
    parsedData = ''
    what.stdout.on 'data', (data) =>
      parsedData = JSON.parse(data)

    what.on 'close', (code) =>
      @emit 'what-complete', parsedData.what.importpath

  command: (cmd) ->
    @nextCommand = cmd
    @what()

  getPath: ->
    return atom.workspaceView.getActiveView()?.getEditor()?.getPath()

  getPosition: ->
    editorView = atom.workspaceView.getActiveView()
    buffer = editorView?.getEditor()?.getBuffer()
    cursor = editorView?.getEditor()?.getCursor()

    startPosition = cursor.getBeginningOfCurrentWordBufferPosition({"includeNonWordCharacters":false})
    endPosition = cursor.getEndOfCurrentWordBufferPosition({"includeNonWordCharacters":false})

    startOffset = buffer.characterIndexForPosition(startPosition)
    endOffset = buffer.characterIndexForPosition(endPosition)

    return [startOffset, endOffset]

  goPath: ->
    gopath = ''
    gopathEnv = process.env.GOPATH
    gopathConfig = atom.config.get('go-oracle.goPath')
    gopath = gopathEnv if gopathEnv? and gopathEnv isnt ''
    gopath = gopathConfig if gopath is ''
    return gopath + '/'
