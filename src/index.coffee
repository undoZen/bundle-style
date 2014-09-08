detective = require('detective')
resolve = require('resolve')
fs = require('fs')
path = require('path')
fileName = __dirname + '/lib/client.js'
chtmlx = require('chtmlx')
iced = require('iced-coffee-script')
_ = require('lodash')
less = require('less')

deps = (fileName) ->

  dirname = path.dirname fileName
  src = fs.readFileSync(fileName, 'utf-8')
  if fileName.match(/\.cx\.html$/i)
    src = iced.compile(chtmlx(src), {header: false, bare: true})
  #console.log src
  d = detective(src)
  #console.log d
  d.map (r) ->
    if r.indexOf('node_modules') > -1
      return null
    if r[0] is '.' and r.match(/\.(css|less)$/i)
      return path.resolve dirname, r
    try
      resolved = resolve.sync r,
        basedir: dirname
      if resolved.match(/\.(css|less)$/i)
        return resolved
      if resolved.indexOf('node_modules') > -1 and resolved.indexOf('ccc-ui') is -1
        return null
      return deps resolved
    catch err
      console.error err.stack
      console.error err
      console.log fileName, r, resolved
      return null

crypto = require('crypto')
md5OfFile = (filepath) ->
  hash = new crypto.Hash('md5')
  hash.update(fs.readFileSync(filepath))
  hash.digest('hex')

module.exports = ->
  console.log 'starting bundle style'
  filePath = path.resolve(__dirname, 'src', 'bundle-style.less')
  cssFilePath = filePath.replace(/\.less$/, '.css')

  requiredStyle = (_.unique _.flatten deps fileName).filter (m) -> m and not m.match(/bundle-style\.css$/i)

  content = requiredStyle
    .map((file) ->
      relativePath = path.relative __dirname+'/src', file
      if relativePath.match(/\.css$/i)
        "/* file: #{file} / md5: #{md5OfFile(file)} */ @import (inline) \"./#{relativePath}\";"
      else
        "/* file: #{file} / md5: #{md5OfFile(file)} */ @import \"./#{relativePath}\";"
    )
    .join('\n')
  if lastContent is content
    return
  lastContent = content
  fs.writeFile filePath, content, 'utf-8', (err) ->
    if err
      console.error err.stack
  parser = new less.Parser
    filename: filePath
    paths: [path.dirname(filePath)]
  parser.parse content, (err, tree) ->
    if err
      console.error err.message
      console.error err
      console.error err.stack
      return

    css = tree.toCSS
      sourceMapBasepath: __dirname
      sourceMapRootpath: 'file:///'
      sourceMap: true

    fs.writeFile cssFilePath, css, 'utf-8', (err) ->
      if err
        console.error err.stack
      console.log 'done bundle style'
