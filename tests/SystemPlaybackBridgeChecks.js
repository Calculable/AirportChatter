// Run: node tests/SystemPlaybackBridgeChecks.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('AirportChatter/Audio/SoundCloudWebPlayer.swift', 'utf8');
const script = source.match(/static let remoteControlScript = """([\s\S]*?)"""/)[1];
function setup(host, mediaSession = true) {
  const handlers = {}, listeners = {}, messages = [];
  const context = {
    location: {hostname: host},
    navigator: mediaSession ? {mediaSession: {setActionHandler: (action, handler) => { handlers[action] = handler; }}} : {},
    document: {addEventListener: (name, handler) => { listeners[name] = handler; }},
    window: {webkit: {messageHandlers: {soundCloudRemote: {postMessage: command => messages.push(command)}}}}
  };
  vm.runInNewContext(script, context);
  return {handlers, listeners, messages};
}
const widget = setup('w.soundcloud.com');
for (const action of ['play', 'pause', 'stop', 'nexttrack', 'previoustrack']) widget.handlers[action]();
assert.deepEqual(widget.messages, ['play', 'pause', 'pause', 'next', 'previous']);
widget.handlers.pause = () => { throw new Error('Widget handler was not refreshed'); };
widget.listeners.play();
widget.handlers.pause();
assert.equal(widget.messages.at(-1), 'pause');
assert.deepEqual(Object.keys(setup('unrelated.example').handlers), []);
assert.deepEqual(Object.keys(setup('w.soundcloud.com', false).handlers), []);
console.log('Web media-session command forwarding and frame scoping passed.');
