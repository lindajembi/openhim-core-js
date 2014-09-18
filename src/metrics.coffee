Transaction = require('./model/transactions').Transaction
Channel = require('./model/channels').Channel
moment = require 'moment'
logger = require 'winston'
mongoose = require 'mongoose'
authorisation = require './api/authorisation'
Q = require 'q'

exports.fetchGlobalLoadTimeMetrics = `function fetchGlobalLoadTimeMetrics(requestingUser, filtersObject){

  var from, to

  if (filtersObject.startDate && filtersObject.endDate){
    from = new Date(JSON.parse(filtersObject.startDate));
    to = new Date(JSON.parse(filtersObject.endDate));
    delete filtersObject.startDate;
    delete filtersObject.endDate;
  } else {
    from =  moment().subtract(1,'weeks').toDate();
    to =  moment().toDate();
  }


  filtersObject['request.timestamp'] = { $lt: to, $gt: from };

  return getAllowedChannelIDs(requestingUser).then(function(allowedChannelIDs){
    filtersObject['channelID'] = { $in : allowedChannelIDs };
    return Transaction.aggregate([
      { $match: filtersObject },
      { $group:
        {
          _id: {
            year:  { $year: "$request.timestamp"},
            month: { $month: "$request.timestamp"},
            day:   { $dayOfMonth: "$request.timestamp"},
            hour:  { $hour: "$request.timestamp"}
          },
          load: { $sum: 1 },
          avgResp: {
            $avg: {
              $subtract : ["$response.timestamp","$request.timestamp"]
            }
          }
        }
      }
    ]).exec();
  });
}`

exports.fetchGlobalStatusMetrics = `function fetchGlobalStatusMetrics(requestingUser, filtersObject){

  var from, to;

   if (filtersObject.startDate && filtersObject.endDate){
    from = new Date(JSON.parse(filtersObject.startDate));
    to = new Date(JSON.parse(filtersObject.endDate));
    //remove startDate/endDate from objects filter (Not part of filtering and will break filter)
      delete filtersObject.startDate;
      delete filtersObject.endDate;
  } else {
    from =  moment().subtract(1,'weeks').toDate();
    to =  moment().toDate();
  }
      filtersObject['request.timestamp'] = { $lt: to, $gt: from }

      return getAllowedChannelIDs(requestingUser).then(function(allowedChannelIDs){
          filtersObject['channelID'] = { $in : allowedChannelIDs };
          return Transaction.aggregate([
            { $match: filtersObject },
            {
              $group: {
                _id: {
                  channelID: "$channelID"
                },
                failed: {
                  $sum: {
                    $cond: [{ $eq: ["$status", 'Failed']}, 1, 0]
                  }
                },
                successful: {
                  $sum: {
                    $cond: [{ $eq: ["$status", 'Successful']}, 1, 0]
                  }
                },
                processing: {
                  $sum: {
                    $cond: [{ $eq: ["$status", 'Processing']}, 1, 0]
                  }
                },
                completed: {
                  $sum: {
                    $cond: [{ $eq: ["$status", 'Completed']}, 1, 0]
                  }
                },
                completedWErrors: {
                  $sum: {
                    $cond: [{ $eq: ["$status", 'Completed with error(s)']}, 1, 0]
                  }
                }
              }
          }
      ]).exec();
    });
}`

exports.fetchChannelMetrics = `function fetchChannelMetrics(time, channelId,userRequesting,filtersObject) {

	var from, to ;
	var data = {};
	    data.body = [];

	var channelID = mongoose.Types.ObjectId(channelId);

  if (filtersObject.startDate && filtersObject.endDate){
    from = new Date(JSON.parse(filtersObject.startDate));
    to = new Date(JSON.parse(filtersObject.endDate));
  } else {
    from =  moment().subtract(1,'days').toDate();
    to =  moment().toDate();
  }



  filtersObject.channelID = channelID;

  if (filtersObject.startDate && filtersObject.endDate) {
    filtersObject['request.timestamp'] = { $lt: to, $gt: from }

    //remove startDate/endDate from objects filter (Not part of filtering and will break filter)
    delete filtersObject.startDate;
    delete filtersObject.endDate;
   }


  var groupObject = {};
  groupObject._id = {};
  groupObject = {
    _id: {
      year: { $year: "$request.timestamp" },
      month: { $month: "$request.timestamp"}
    },
    load: { $sum: 1},
    avgResp: {
      $avg: {
        $subtract: ["$response.timestamp", "$request.timestamp"]
      }
    }
  };

  switch (time){
    case 'minute':
      groupObject._id.day = { $dayOfMonth :  "$request.timestamp"};
      groupObject._id.hour = { $hour : "$request.timestamp" };
      groupObject._id.minute = { $minute : "$request.timestamp"};
      break;
    case 'hour':
      groupObject._id.day = { $dayOfMonth :  "$request.timestamp"};
      groupObject._id.hour = { $hour : "$request.timestamp" };
      break;
    case 'day':
      groupObject._id.day = { $dayOfMonth :  "$request.timestamp"};
      break;
    case 'week':
      groupObject._id.week ={ $week : "$request.timestamp"};
      break;
    case 'month':

      break;
    case 'year':
      delete groupObject._id.month;
      break;
    case 'status':
      groupObject = {
          _id: {
            channelID: "$channelID"
          },
          failed: {
            $sum: {
              $cond: [{ $eq: ["$status", 'Failed']}, 1, 0]
            }
          },
          successful: {
            $sum: {
              $cond: [{ $eq: ["$status", 'Successful']}, 1, 0]
            }
          },
          processing: {
            $sum: {
              $cond: [{ $eq: ["$status", 'Processing']}, 1, 0]
            }
          },
          completed: {
            $sum: {
              $cond: [{ $eq: ["$status", 'Completed']}, 1, 0]
            }
          },
          completedWErrors: {
            $sum: {
              $cond: [{ $eq: ["$status", 'Completed with error(s)']}, 1, 0]
            }
          }
        }

      break;
    default :
      //do nothng
      break;
  }
  return Transaction.aggregate([
      { $match: filtersObject },
      { $group: groupObject }
      ]).exec()
}`

getAllowedChannels = (requestingUser) ->
  authorisation.getUserViewableChannels requestingUser
  .then (allowedChannelsArray)->

    allowedChannelIDs = [];
    promises = []

    for channel in allowedChannelsArray
      do (channel) ->
        deferred = Q.defer()
        allowedChannelIDs.push
          id: channel._id
          name: channel.name

        deferred.resolve()
        promises.push deferred.promise

    (Q.all promises).then ->
      allowedChannelIDs

getAllowedChannelIDs = (requestingUser) ->
  authorisation.getUserViewableChannels requestingUser
  .then (allowedChannelsArray)->

    allowedChannelIDs = [];
    promises = []

    for channel in allowedChannelsArray
      do (channel) ->
        deferred = Q.defer()
        allowedChannelIDs.push channel._id

        deferred.resolve()
        promises.push deferred.promise

    (Q.all promises).then ->
      allowedChannelIDs


exports.getAllowedChannels = getAllowedChannels
exports.getAllowedChannelIDs = getAllowedChannelIDs