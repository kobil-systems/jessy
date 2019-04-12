%% The MIT License

%% Copyright (c) 2014 alisdair sullivan <alisdairsullivan@yahoo.ca>

%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:

%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.

-module(jsonpointer).

-export([encode/1, decode/1, ref_to_int/1]).


encode(Refs) when is_list(Refs) -> encode(Refs, <<>>).

encode([], Bin) -> Bin;
encode([Ref|Rest], Bin)
when is_binary(Ref) ->
    encode(Rest, <<Bin/binary, $/, (escape(Ref))/binary>>);
encode([Ref|Rest], Bin)
when is_integer(Ref) ->
    IntBin = unicode:characters_to_binary(integer_to_list(Ref)),
    encode(Rest, <<Bin/binary, $/, IntBin/binary>>);
encode([Ref|Rest], Bin)
when is_atom(Ref) ->
    encode(Rest, <<Bin/binary, $/, (unicode:characters_to_binary(atom_to_list(Ref)))/binary>>).


decode(Bin) -> decode(Bin, []).

decode(<<>>, Acc) -> lists:reverse(Acc);
decode(<<$~, $0, Rest/binary>>, [Current|Done]) ->
    decode(Rest, [<<Current/binary, $~>>] ++ Done);
decode(<<$~, $1, Rest/binary>>, [Current|Done]) ->
    decode(Rest, [<<Current/binary, $/>>] ++ Done);
decode(<<$/, Rest/binary>>, []) ->
    decode(Rest, [<<>>]);
decode(<<$/, Rest/binary>>, [Current|Done]) ->
    decode(Rest, [<<>>, Current] ++ Done);
decode(<<Codepoint/utf8, Rest/binary>>, [Current|Done]) ->
    decode(Rest, [<<Current/binary, Codepoint/utf8>>] ++ Done).


escape(Ref) -> escape(Ref, <<>>).

escape(<<>>, Acc) -> Acc;
escape(<<$~, Rest/binary>>, Acc) -> escape(Rest, <<Acc/binary, $~, $0>>);
escape(<<$/, Rest/binary>>, Acc) -> escape(Rest, <<Acc/binary, $~, $1>>);
escape(<<Codepoint/utf8, Rest/binary>>, Acc) -> escape(Rest, <<Acc/binary, Codepoint>>).


ref_to_int(<<"0">>) -> 0;
ref_to_int(<<Digit/utf8, _/binary>> = Ref)
when Digit >= $1, Digit =< $9 ->
    binary_to_integer(Ref);
ref_to_int(_) -> erlang:error(badarg).


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").


encode_test_() ->
    [
        {"root path", ?_assertEqual(<<>>, encode([]))},
        {"single reference", ?_assertEqual(
            <<"/foo">>,
            encode([<<"foo">>])
        )},
        {"multiple references", ?_assertEqual(
            <<"/foo/bar/baz">>,
            encode([<<"foo">>, <<"bar">>, <<"baz">>])
        )},
        {"integer reference", ?_assertEqual(
            <<"/foo/0/1/2">>,
            encode([<<"foo">>, 0, 1, 2])
        )},
        {"~ in reference", ?_assertEqual(
            <<"/~0/a~0a/~0foo/foo~0">>,
            encode([<<"~">>, <<"a~a">>, <<"~foo">>, <<"foo~">>])
        )},
        {"/ in reference", ?_assertEqual(
            <<"/~1/a~1a/~1foo/foo~1">>,
            encode([<<"/">>, <<"a/a">>, <<"/foo">>, <<"foo/">>])
        )},
        {"integer in reference", ?_assertEqual(
            <<"/foo/1">>,
            encode([<<"foo">>, 1])
        )},
        {"atom in reference", ?_assertEqual(
            <<"/foo/bar">>,
            encode([foo, bar])
        )}
    ].

decode_test_() ->
    [
        {"root path", ?_assertEqual([], decode(<<>>))},
        {"single reference", ?_assertEqual(
            [<<"foo">>],
            decode(<<"/foo">>)
        )},
        {"multiple references", ?_assertEqual(
            [<<"foo">>, <<"bar">>, <<"baz">>],
            decode(<<"/foo/bar/baz">>)
        )},
        {"~ in reference", ?_assertEqual(
            [<<"~">>, <<"a~a">>, <<"~foo">>, <<"foo~">>],
            decode(<<"/~0/a~0a/~0foo/foo~0">>)
        )},
        {"/ in reference", ?_assertEqual(
            [<<"/">>, <<"a/a">>, <<"/foo">>, <<"foo/">>],
            decode(<<"/~1/a~1a/~1foo/foo~1">>)
        )},
        {"~01 in reference", ?_assertEqual(
            [<<"~1">>],
            decode(<<"/~01">>)
        )}
    ].

ref_to_int_test_() ->
    [
        {"0", ?_assertEqual(0, ref_to_int(<<"0">>))},
        {"123456789", ?_assertEqual(123456789, ref_to_int(<<"123456789">>))},
        {"01", ?_assertError(badarg, ref_to_int(<<"01">>))}
    ].

-endif.