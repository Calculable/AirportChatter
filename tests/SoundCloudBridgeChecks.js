// Run: node tests/SoundCloudBridgeChecks.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('AirportChatter/Audio/SoundCloudWebPlayer.swift', 'utf8');
const script = source.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
const events = {}, messages = [], calls = [];
let paused = true, pendingQuery;
const widget = {
  bind: (event, handler) => { events[event] = handler; },
  play: () => calls.push('play'), pause: () => calls.push('pause'),
  next: () => calls.push('next'), prev: () => calls.push('prev'),
  setVolume: value => calls.push(['volume', value]),
  isPaused: callback => { pendingQuery = callback; }
};
const Widget = () => widget;
Widget.Events = Object.fromEntries(['READY', 'PLAY', 'PAUSE', 'FINISH', 'ERROR'].map(x => [x, x]));
const context = { document: { getElementById: () => ({}) }, SC: { Widget }, window: { webkit: { messageHandlers: { soundCloud: { postMessage: value => messages.push(value) } } } } };
vm.runInNewContext(script, context);
for (const event of ['READY', 'PLAY', 'PAUSE', 'FINISH', 'ERROR']) events[event]();
assert.deepEqual(messages, ['ready', 'playing', 'paused', 'finished', 'error']);
const control = context.window.nativeSoundCloudControl;
control('setVolume', 0);
assert.deepEqual(calls.pop(), ['volume', 0]);
control('next'); pendingQuery(true);
assert.deepEqual(calls.splice(0), ['next', 'pause']);
control('prev'); pendingQuery(false);
assert.deepEqual(calls.splice(0), ['prev', 'play']);
control('next'); const stale = pendingQuery;
control('pause'); stale(false);
assert.deepEqual(calls.splice(0), ['pause']);
console.log('SoundCloud events, mute, previous/next state preservation, and rapid pause checks passed.');
