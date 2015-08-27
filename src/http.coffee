URL                = require 'url'
JSONStream         = require 'JSONStream'
# http               = require 'http'
# request         = require 'superagent'
request = require 'request'
{ACCEPT_HEADER}    = require './constants'
{VERSION}          = require './version'
{error, defer, merge, invoke} = utils = require('./util')

# The user-agent string we will use to identify ourselves
USER_AGENT = "node-http/imjs-#{ VERSION }"

# Pattern to match optional trailing commas
PESKY_COMMA = /,\s*$/

# The urlencoded content-type.
URLENC = "application/x-www-form-urlencoded"

# Get the method we should actually use to make a request of
# method 'x'.
#
# @param [String] x The method I'm thinking of using.
# @return [String] y The method you should actually use.
#
# Not required if the implementation supports all methods.

# Whether or not this service supports the given method
# The default implementation returns true for all inputs.
exports.supports = -> true

# The function to use when streaming results one by
# one from the connection, rather than buffering them all
# in memory.
streaming = (opts, resolve, reject) -> (resp) ->
  #console.log "straming"
  if not resp.pipe?
    return reject new Error 'response is not a stream'

  resp.on 'error', reject

  # We pause streams because all our handlers are probably not attched yet.

  if resp.statusCode? and resp.statusCode isnt 200
    errors = JSONStream.parse 'error'
    errors.pause()
    resp.pipe errors
    reject [resp.statusCode, errors]
  else
    results = JSONStream.parse 'results.*'
    results.pause()
    resp.pipe(results)
    resolve results

# Get a message that explains what went wrong.
getMsg = ({type, url}, text, e, code) ->
  """Could not parse response to #{ type } #{ url }: "#{ text }" (#{ code }: #{ e })"""

blocking = (opts, resolve, reject) -> (resp) ->
  #console.log "blocking"
  #console.log "blocking opts", opts
  # #console.log "resp is", resp
  containerBuffer = ''
  resp.on 'data', (chunk) -> containerBuffer += chunk
  resp.on 'error', reject
  resp.on 'end', ->
    #console.log "BLOCKING HAS ENDED"
    ct = resp.headers['content-type']
    #console.log "GOT CT", ct
    if 'application/json' is ct or /json/.test(opts.dataType) or /json/.test opts.data.format
      if '' is containerBuffer and resp.statusCode is 200
        # No body, but success.
        #console.log "NO BODY"
        resolve()
      else
        #console.log "TRYING TO PARSE HEADERS"
        try
          parsed = JSON.parse containerBuffer
          #console.log "got after parsed"
          if err = parsed.error
            #console.log "got a parsed error"
            #console.log "err", err
            reject new Error(err)
          else
            #console.log "RESOLVING TO TRUE"
            resolve parsed
        catch e
          #console.log "GOT AN ERROR2"
          if resp.statusCode >= 400
            reject new Error(resp.statusCode)
          else
            reject new Error(getMsg opts, containerBuffer, e, resp.statusCode)
    else
      #console.log "UH OH"
      if match = containerBuffer.match /\[ERROR\] (\d+)([\s\S]*)/
        reject new Error(match[2])
      else
        f = if (200 <= resp.statusCode < 400) then resolve else reject
        f containerBuffer

# Return a function to be called in as a method of a service instance.
exports.iterReq = (method, path, format) -> (q, page = {}, cb = (->), eb = (->), onEnd = (->)) ->
  if utils.isFunction(page)
    [page, cb, eb, onEnd] = [{}, page, cb, eb]
  req = merge {format}, page, query: q.toXML()
  attach = (stream) ->
    stream.on 'data', cb
    stream.on 'error', eb
    stream.on 'end', onEnd
    setTimeout (-> stream.resume() if stream.resume?), 3 # Allow handlers in promises to attach.
    return stream
  readErrors = ([sc, errors]) ->
    errors.on 'data', eb
    errors.on 'error', eb
    errors.on 'end', onEnd
    errors.resume() if errors.resume?
    error sc
  promise = @makeRequest(method, path, req, null, true)
  promise.then attach, readErrors
  return promise

rejectAfter = (timeout, reject, promise) ->
  to = setTimeout (-> reject "Request timed out."), timeout
  promise.then -> cancelTimeout to

parseOptions = (opts) ->
  #console.log "parseoptions are", opts
  if not opts.url
    throw new Error("No url provided in #{ JSON.stringify opts }")

  if typeof opts.data is 'string'
    postdata = opts.data
    if opts.type in [ 'GET', 'DELETE' ]
      throw new Error("Invalid request. #{ opts.type } requests must not have bodies")
  else
    postdata = utils.querystring opts.data

  parsed = URL.parse(opts.url, true)
  #console.log "PARSED", parsed
  parsed.withCredentials = false
  parsed.method = (opts.type || 'GET')
  if opts.port?
    parsed.port = opts.port
  parsed.headers =
    'User-Agent': USER_AGENT
    'Accept': ACCEPT_HEADER[opts.dataType]

  if parsed.method in ['GET', 'DELETE'] and postdata?.length
    sep = if /\?/.test(parsed.path) then '&' else '?'
    parsed.path += sep + postdata
    postdata = null
  else
    parsed.headers['Content-Type'] = (opts.contentType or URLENC) + '; charset=UTF-8'
    parsed.headers['Content-Length'] = postdata.length

  if opts.headers?
    parsed.headers[k] = v for k, v of opts.headers
  if opts.auth?
    parsed.auth = opts.auth
    #console.log "auth"
    #console.log parsed.auth

  #console.log "-----------finished parsed", parsed

  return [parsed, postdata]

exports.doReq = (opts, iter) ->
  debugger
  #console.log "DOREQOPTS", opts
  #console.log "HEADERS", opts.headers
  # opts.type = opts.method
  {promise, resolve, reject} = defer()
  promise.then null, opts.error

  try
    [url, postdata] = parseOptions opts
    handler = (if iter then streaming else blocking) opts, resolve, reject

    # We construct the request here.
    # req = http.request url, handler
    console.log "CONSTRUCTING WITH", url
    req = request url.href, url
    # req.method = url.method


    # if url.headers?
    #   try
    #   req.set url.headers
      #console.log "finished setting headers"
      #console.log "headers are now", req.headers
    # else
      #console.log "no need to set headers"
    #console.log "finishing the header check"
    req.parse handler

    req.on 'error', (err) -> reject new Error "Error: #{ url.method } #{ opts.url }: #{ err }"

    if postdata?
      #console.log "has post data"
      #console.log postdata
      # req2.write postdata
      req.send postdata
      # #console.log "req is now", req

    #console.log "REQIS"
    #console.log req
    #console.log "******************************"



    # And sent it off here.
    req.end()
    # req2.end()

    timeout = opts.timeout

    if timeout > 0
      rejectAfter timeout, reject, promise

  catch e
    reject e

  return promise
