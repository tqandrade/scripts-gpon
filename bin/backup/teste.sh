#!/bin/bash
db.getCollection('devices').find({_id: /.*3B08EE7F$/}, {_id: 1})

