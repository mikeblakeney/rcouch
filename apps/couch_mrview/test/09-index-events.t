#!/usr/bin/env escript
%% -*- erlang -*-

% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.

main(_) ->
    etap:plan(5),
    case (catch test()) of
        ok ->
            etap:end_tests();
        Other ->
            etap:diag(io_lib:format("Test died abnormally: ~p", [Other])),
            etap:bail(Other)
    end,
    timer:sleep(300),
    ok.

test() ->
    test_util:start_couch(),
    {ok, Db} = couch_mrview_test_util:init_db(<<"foo">>, changes),
    test_info(Db),
    test_update_event(Db),
    test_delete_event(Db),
    test_util:stop_couch(),
    ok.

test_info(Db) ->
    {ok, Info} = couch_mrview:get_info(Db, <<"_design/bar">>),
    etap:is(getval(update_options, Info), [<<"keyseq_indexed">>,
                                           <<"seq_indexed">>],
            "update options OK"),
    ok.

test_update_event(Db) ->
    {ok, Pid} = couch_index_event:start_link(self()),
    etap:ok(is_pid(Pid), "event handler added"),
    ok = couch_mrview:refresh(Db, <<"_design/bar">>),
    Expect = {index_update, {<<"foo">>, <<"_design/bar">>,
                             couch_mrview_index}},
    receive
        Event ->
            etap:is(Event, Expect, "index update events OK")
    end,
    couch_index_event:stop(Pid).

test_delete_event(Db) ->
    ok = couch_mrview:refresh(Db, <<"_design/bar">>),
    timer:sleep(300),
    {ok, Pid} = couch_index_event:start_link(self()),
    etap:ok(is_pid(Pid), "delete event handler added"),


    catch couch_mrview_test_util:delete_db(<<"foo">>),
    Expect = {index_delete, {<<"foo">>, <<"_design/bar">>,
                             couch_mrview_index}},
    receive
        Event ->
            etap:is(Event, Expect, "index delete events OK")
    end,
    couch_index_event:stop(Pid).

getval(Key, PL) ->
    {value, {Key, Val}} = lists:keysearch(Key, 1, PL),
    Val.
