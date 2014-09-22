detective = require('detective')
resolve = require('resolve')
fs = require('fs')
path = require('path')
chtmlx = require('chtmlx')
iced = require('iced-coffee-script')
_ = require('lodash')
less = require('less')

env = process.env.NODE_ENV ? 'development'

deps = (fileName) ->

  _added = {}
  _deps = (_fileName) ->
    dirname = path.dirname _fileName
    src = fs.readFileSync(_fileName, 'utf-8')
    if _fileName.match(/\.cx\.html$/i)
      src = iced.compile(chtmlx(src), {header: false, bare: true})
    #console.log src
    d = detective(src)
    #console.log d
    d.map (r) ->
      resolved = resolve.sync r,
        basedir: dirname
      if _added[resolved]
        return null
      _added[resolved] = true
      if r.indexOf('node_modules') > -1
        return null
      if r[0] is '.' and r.match(/\.(css|less)$/i)
        return path.resolve dirname, r
      try
        if resolved.match(/\.(css|less)$/i)
          return resolved
        if resolved.indexOf('node_modules') > -1 and resolved.indexOf('ccc-') is -1
          return null
        return _deps resolved
      catch err
        console.error err.stack
        console.error err
        console.log _fileName, r, resolved
        return null
  _.unique _.flatten _deps fileName

crypto = require('crypto')
md5OfFile = (filepath) ->
  hash = new crypto.Hash('md5')
  hash.update(fs.readFileSync(filepath))
  hash.digest('hex')

module.exports = class BundleStyle
  constructor: (@fileName) ->
    if @ not instanceof BundleStyle
      return new BundleStyle(fileName)
    @dirPath = path.dirname(@fileName)
    @lessFilePath = path.resolve(@dirPath, 'bundle-style.less')
    @cssFilePath = @lessFilePath.replace(/\.less$/, '.css')
    @lastContent = @lastContent || false
    @content = ''

  generateLess: ->
    console.log 'generating less'
    @content = deps @fileName
      .filter((m) -> m and not m.match(/bundle-style\.css$/i))
      .map((file) =>
        relativePath = path.relative @dirPath, file
        if relativePath.match(/\.css$/i)
          "/* file: #{file} / md5: #{md5OfFile(file)} */ @import (inline) \"./#{relativePath}\";"
        else
          "/* file: #{file} / md5: #{md5OfFile(file)} */ @import \"./#{relativePath}\";"
      )
      .join('\n')
    if @lastContent is @content
      return
    @lastContent = @content
    fs.writeFileSync @lessFilePath, @content, 'utf-8'
    @compileLess()

  compileLess: ->
    console.log 'recompiling css'
    parser = new less.Parser
      filename: @lessFilePath
      paths: [path.dirname(@lessFilePath)]
    parser.parse @content, (err, tree) =>
      if err
        console.error err.message
        console.error err
        console.error err.stack
        return

      cssOptions = {}
      if env is 'development'
        cssOptions =
          sourceMapBasepath: @dirPath
          sourceMapRootpath: 'file:///'
          sourceMap: true
      css = tree.toCSS cssOptions

      fs.writeFile @cssFilePath, css, 'utf-8', (err) ->
        if err
          console.error err.stack
        console.log 'done bundle style'

  generateCss: ->
    @generateLess()
    if @lastContent is @content
      return
    @compileLess()
