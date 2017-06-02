import logger from 'winston';
import moment from 'moment';
import Q from 'q';
import authorisation from './authorisation';
import utils from "../utils";

let levels = {
  debug: 1,
  info: 2,
  warn: 3,
  error: 4
};

export function getLogs() {
  // Only admins can view server logs
  if (!authorisation.inGroup('admin', this.authenticated)) {
    utils.logAndSetResponse(this, 403, `User ${this.authenticated.email} is not an admin, API access to getLogs denied.`, 'info');
    return;
  }

  let { query } = this.request;
  if ((query == null)) {
    query = {};
  }

  // default to info level logs
  if ((query.level == null)) {
    query.level = 'info';
  }

  let options = {
    from: query.from || moment().subtract(5, 'minutes').toDate(),
    until: query.until || new Date,
    order: 'asc',
    start: (parseInt(query.start)) || 0,
    limit: 100000 // limit: 0 doesn't work :/
  };

  let results = {}; //TODO:Fix yield Q.ninvoke logger, 'query', options
  results = results.mongodb;

  if (query.level != null) {
    results = results.filter(item => levels[item.level] >= levels[query.level]);
  }

  if (query.limit != null) {
    results.splice(query.limit, results.length-query.limit);
  }

  this.body = results;
  return this.status = 200;
}
