/**
 * Copyright 2012 Tsvetan Tsvetkov
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Author: Tsvetan Tsvetkov (tsekach@gmail.com)
 */
(function(e){function m(t,n){var r;return e.Notification?r=new e.Notification(t,{icon:c(n.icon)?n.icon:n.icon.x32,body:n.body||u,tag:n.tag||u}):e.webkitNotifications?(r=e.webkitNotifications.createNotification(n.icon,t,n.body),r.show()):navigator.mozNotification?(r=navigator.mozNotification.createNotification(t,n.body,n.icon),r.show()):e.external&&e.external.msIsSiteMode()&&(e.external.msSiteModeClearIconOverlay(),e.external.msSiteModeSetIconOverlay(c(n.icon)?n.icon:n.icon.x16,t),e.external.msSiteModeActivate(),r={ieVerification:f+1}),r}function g(t){return{close:function(){t&&(t.close?t.close():e.external&&e.external.msIsSiteMode()&&t.ieVerification===f&&e.external.msSiteModeClearIconOverlay())}}}function y(t){if(!a)return;var n=l(t)?t:d;e.webkitNotifications&&e.webkitNotifications.checkPermission?e.webkitNotifications.requestPermission(n):e.Notification&&e.Notification.requestPermission&&e.Notification.requestPermission(n)}function b(){var r;if(!a)return;return e.Notification&&e.Notification.permissionLevel?r=e.Notification.permissionLevel():e.webkitNotifications&&e.webkitNotifications.checkPermission?r=i[e.webkitNotifications.checkPermission()]:navigator.mozNotification?r=n:e.Notification&&e.Notification.permission?r=e.Notification.permission:e.external&&e.external.msIsSiteMode()!==undefined&&(r=e.external.msIsSiteMode()?n:t),r}function w(e){return e&&h(e)&&p(v,e),v}function E(){return v.pageVisibility?document.hidden||document.msHidden||document.mozHidden||document.webkitHidden:!0}function S(t,r){var i,s;return a&&E()&&c(t)&&r&&(c(r.icon)||h(r.icon))&&b()===n&&(i=m(t,r)),s=g(i),v.autoClose&&i&&!i.ieVerification&&i.addEventListener&&i.addEventListener("show",function(){var t=s;e.setTimeout(function(){t.close()},v.autoClose)}),s}var t="default",n="granted",r="denied",i=[n,t,r],s={pageVisibility:!1,autoClose:0},o={},u="",a=function(){var t=!1;try{t=!!(e.Notification||e.webkitNotifications||navigator.mozNotification||e.external&&e.external.msIsSiteMode()!==undefined)}catch(n){}return t}(),f=Math.floor(Math.random()*10+1),l=function(e){return e&&e.constructor===Function},c=function(e){return e&&e.constructor===String},h=function(e){return e&&e.constructor===Object},p=function(e,t){var n,r;for(n in t){r=t[n];if(!(n in e)||e[n]!==r&&(!(n in o)||o[n]!==r))e[n]=r}return e},d=function(){},v=s;e.notify={PERMISSION_DEFAULT:t,PERMISSION_GRANTED:n,PERMISSION_DENIED:r,isSupported:a,config:w,createNotification:S,permissionLevel:b,requestPermission:y},l(Object.seal)&&Object.seal(e.notify)})(window);