/**
 * Copyright (c) 2014 Hewlett-Packard.
 * All Rights Reserved.
 *
 * This software is the confidential and proprietary information of
 * Hewlett-Packard, Inc.
 *
 * Source code style and conventions follow the "ISS Development Guide Java
 * Coding Conventions" standard dated 01/12/2011.
 */

/**
 * Intent plugin plugin.
 * @author Alejandro Gomez <amoron@emergya.com>
 */
function IntentPlugin() {
  'use strict';
}

IntentPlugin.prototype.getCordovaIntent = function (successCallback, failureCallback) {
  'use strict';

  return cordova.exec(
    successCallback,
    failureCallback,
    "IntentPlugin",
    "getCordovaIntent",
    []
    );
};

IntentPlugin.prototype.setNewIntentHandler = function (method) {
  'use strict';

  cordova.exec(
    method,
    null,
    "IntentPlugin",
    "setNewIntentHandler",
    [method]
    );
};

IntentPlugin.prototype.getRealPathFromContentUrl = function (uri, successCallback, failureCallback) {
  'use strict'

  cordova.exec(
    successCallback,
    failureCallback,
    'IntentPlugin',
    'getRealPathFromContentUrl',
    [uri]
    );

}

var intentInstance = new IntentPlugin();
module.exports = intentInstance;

// Make plugin work under window.plugins
if (!window.plugins) {
  window.plugins = {};
}
if (!window.plugins.intent) {
  window.plugins.intent = intentInstance;
}