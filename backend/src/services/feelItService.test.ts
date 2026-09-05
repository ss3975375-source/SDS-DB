import test from 'node:test';
import assert from 'node:assert/strict';

import { validateFeelItInput } from './feelItService.js';
test('Feel It requires text or media',()=>{assert.equal(validateFeelItInput({visibility:'contacts',userIds:[]}), 'CONTENT_REQUIRED');});
test('Feel It selected visibility requires recipients',()=>{assert.equal(validateFeelItInput({text:'hello',visibility:'selected',userIds:[]}), 'RECIPIENTS_REQUIRED');});
test('Feel It cannot accept recipient list for contacts mode',()=>{assert.equal(validateFeelItInput({text:'hello',visibility:'contacts',userIds:['11111111-1111-1111-1111-111111111111']}), 'INVALID_RECIPIENTS');});
test('Feel It text is capped at 10000 characters',()=>{assert.equal(validateFeelItInput({text:'x'.repeat(10001),visibility:'contacts',userIds:[]}), 'TEXT_TOO_LONG');});
