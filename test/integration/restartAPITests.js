import should from "should";
import sinon from "sinon";
import request from "supertest";
import { Transaction } from "../../lib/model/transactions";
import { Channel } from "../../lib/model/channels";
import { User } from '../../lib/model/users';
import server from "../../lib/server";
import testUtils from "../testUtils";
import { auth } from "../testUtils";

describe("API Integration Tests", () =>

  describe("Restart REST Api testing", function() {
    let transactionId = null;
    let requ = {
      path: "/api/test",
      headers: {
        "header-title": "header1-value",
        "another-header": "another-header-value"
      },
      querystring: "param1=value1&param2=value2",
      body: "<HTTP body request>",
      method: "POST",
      timestamp: "2014-06-09T11:17:25.929Z"
    };

    let respo = {
      status: "200",
      headers: {
        header: "value",
        header2: "value2"
      },
      body: "<HTTP response>",
      timestamp: "2014-06-09T11:17:25.929Z"
    };

    let transactionData = {
      status: "Processing",
      clientID: "999999999999999999999999",
      channelID: "888888888888888888888888",
      request: requ,
      response: respo,
        
      routes:
        [{
          name: "dummy-route",
          request: requ,
          response: respo
        }
        ],

      orchestrations:
        [{
          name: "dummy-orchestration",
          request: requ,
          response: respo
        }
        ],
      properties: { 
        property: "prop1", value: "prop1-value1",
        property:"prop2", value: "prop-value1"
      }
    };

    let authDetails = {};

    let channel = new Channel({
      name: "TestChannel1",
      urlPattern: "test/sample",
      allow: [ "PoC", "Test1", "Test2" ],
      routes: [{
            name: "test route",
            host: "localhost",
            port: 9876,
            primary: true
          }
          ],
      txViewAcl: [ "group1" ],
      txViewFullAcl: []});

    before(done =>
      auth.setupTestUsers(err =>
        channel.save(err =>
          server.start({apiPort: 8080}, () => done())
        )
      )
    );

    after(done =>
      auth.cleanupTestUsers(err =>
        Channel.remove(err =>
          server.stop(() => done())
        )
      )
    );

    beforeEach(() => authDetails = auth.getAuthDetails());

    return describe("*restart()", function() {

      it("should successfully send API request to restart the server", function(done) {
        let stub = sinon.stub(server, 'startRestartServerTimeout');
        return request("https://localhost:8080")
          .post("/restart")
          .set("auth-username", testUtils.rootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send()
          .expect(200)
          .end(function(err, res) {
            if (err) {
              return done(err);
            } else {
              stub.calledOnce.should.be.true;
              return done();
            }
        });
      });

      return it("should not allow non admin user to restart the server", done =>
        request("https://localhost:8080")
          .post("/restart")
          .set("auth-username", testUtils.nonRootUser.email)
          .set("auth-ts", authDetails.authTS)
          .set("auth-salt", authDetails.authSalt)
          .set("auth-token", authDetails.authToken)
          .send()
          .expect(403)
          .end(function(err, res) {
            if (err) {
              return done(err);
            } else {
              return done();
            }
        })
      );
    });
  })
);

