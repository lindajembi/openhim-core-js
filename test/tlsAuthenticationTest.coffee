fs = require "fs"
should = require "should"
sinon = require "sinon"
tlsAuthentication = require "../lib/tlsAuthentication"
Application = require("../lib/applications").Application

describe "Setup mutual TLS", ->
	it "should add all trusted certificates and enable mutual auth from all applications to server options if mutual auth is enabled", ->

		cert = (fs.readFileSync "test/client-tls/cert.pem").toString()

		testAppDoc =
			applicationID: "testApp"
			domain: "test-client.jembi.org"
			name: "TEST Application"
			roles:
				[ 
					"OpenMRS_PoC"
					"PoC" 
				]
			passwordHash: ""
			cert: cert

		app = new Application testAppDoc
		app.save (error, newAppDoc) ->
			tlsAuthentication.getServerOptions true, (err, options) ->
				options.ca.should.be.ok
				options.ca.should.be.an.Array
				options.ca.should.containEql cert
				options.requestCert.should.be.true
				options.rejectUnauthorized.should.be.false


	it "should NOT have mutual auth options set if mutual auth is disabled", ->
		tlsAuthentication.getServerOptions false, (err, options) ->
			options.should.not.have.property "ca"
			options.should.not.have.property "requestCert"
			options.should.not.have.property "rejectUnauthorized"
	it "should add the servers key and certificate to the server options", ->
		tlsAuthentication.getServerOptions false, (err, options) ->
			options.cert.should.be.ok
			options.key.should.be.ok

	after (done) ->
		Application.remove { applicationID: "testApp" }, ->
			done()