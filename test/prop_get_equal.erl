-module(prop_get_equal).
-include_lib("proper/include/proper.hrl").

%%%%%%%%%%%%%%%%%%
%%% Properties %%%
%%%%%%%%%%%%%%%%%%
prop_get_equal() ->
    ?FORALL(Type, resize(10, json_list()),
        begin
            boolean(Type)
        end).

%%%%%%%%%%%%%%%
%%% Helpers %%%
%%%%%%%%%%%%%%%
boolean(Type) ->
    Draft3Equal = jesse_lib:is_equal(
        jesse_lib:normalize_and_sort(Type, 3),
        Type,
        3),
    Draft4Equal = jesse_lib:is_equal(
        jesse_lib:normalize_and_sort(Type, 4),
        Type,
        4),
    Draft3Equal and Draft4Equal.

%%%%%%%%%%%%%%%%%%
%%% Generators %%%
%%%%%%%%%%%%%%%%%%
json_list() -> list(proper_json:json()).
