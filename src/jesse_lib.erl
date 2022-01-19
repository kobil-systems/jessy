%%%=============================================================================
%% Copyright 2012- Klarna AB
%% Copyright 2015- AUTHORS
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% @doc Json schema validation module.
%%
%% This module is the core of jesse, it implements the validation functionality
%% according to the standard.
%% @end
%%%=============================================================================

-module(jesse_lib).

%% API
-export([ empty_if_not_found/1
        , is_array/1
        , is_json_object/1
        , is_json_object_empty/1
        , is_null/1
        , normalize_and_sort/1
        , is_equal/2
        ]).

%% Includes
-include("jesse_schema_validator.hrl").

%%% API
%% @doc Returns an empty list if the given value is ?not_found.
-spec empty_if_not_found(Value :: any()) -> any().
empty_if_not_found(?not_found) ->
  [];
empty_if_not_found(Value) ->
  Value.

%% @doc Checks if the given value is json `array'.
%% This check is needed since objects in `jsx' are lists (proplists).
-spec is_array(Value :: any()) -> boolean().
is_array(Value)
  when is_list(Value) ->
  not is_json_object(Value);
is_array(_) ->
  false.

%% @doc A naive check if the given data is a json object.
%% Supports two main formats of json representation:
%% 1) mochijson2 format (`{struct, proplist()}')
%% 2) jiffy format (`{proplist()}')
%% 3) jsx format (`[{binary() | atom(), any()}]')
%% Returns `true' if the given data is an object, otherwise `false' is returned.
-spec is_json_object(Value :: any()) -> boolean().
?IF_MAPS(
is_json_object(Map)
  when erlang:is_map(Map) ->
  true;
)
is_json_object({struct, Value})
  when is_list(Value) ->
  true;
is_json_object({Value})
  when is_list(Value) ->
  true;
%% handle `jsx' empty objects
is_json_object([{}]) ->
  true;
%% very naive check. checks only the first element.
is_json_object([{Key, _Value} | _])
  when is_binary(Key) orelse is_atom(Key)
       andalso Key =/= struct ->
  true;
is_json_object(_) ->
  false.

%% @doc Checks if the given value is json `null'.
-spec is_null(Value :: any()) -> boolean().
is_null(null) ->
  true;
is_null(_Value) ->
  false.

%% @doc check if json object is_empty.
-spec is_json_object_empty(Value :: any()) -> boolean().
is_json_object_empty({struct, Value})
  when is_list(Value) andalso Value =:= [] ->
  true;
is_json_object_empty({Value})
  when is_list(Value)
       andalso Value =:= [] ->
  true;
%% handle `jsx' empty objects
is_json_object_empty([{}]) ->
  true;
?IF_MAPS(
is_json_object_empty(Map)
  when erlang:is_map(Map) ->
  maps:size(Map) =:= 0;
)
is_json_object_empty(_) ->
  false.

%% @doc Returns a JSON object in which all lists for
%% which order is not relevant will be sorted.  In this way, there
%% will be no differences between objects that contain one of those
%% lists with the same elements but in different order.  Lists for
%% which order is relevant, e.g. JSON arrays, keep their original
%% order and will be considered diffferent if the order is different.
-spec normalize_and_sort(Value :: any()) -> any().
normalize_and_sort(Value) ->
  normalize_and_sort_check_object(Value).

%% This code would look much better if we could use normalize_and_sort_check_object
%% as a guard expression, but that is not possible.  So we need to check
%% in every recurssion step, first if the Value is a JSON object with
%% properties, and in that case call a different function for this values.
%% @private
-spec normalize_and_sort_check_object(Value :: any()) -> any().
normalize_and_sort_check_object(Value) ->
  case jesse_lib:is_json_object(Value) of
    true -> normalize_and_sort_object(Value);
    false -> normalize_and_sort_non_object(Value)
  end.

%% This function covers the recursion over:
%% - properties within an object, seen as tuples. In that case, we run
%%   the normalization/ordering over the values of these properties.
%% - JSON arrays, seen as lists. In that case, we keep the order of
%%   the list and run the normalization/ordering over each of the values
%%   in the list.
%% - Basic JSON types. In that case, we just return the value.
%% @private
-spec normalize_and_sort_non_object(Value :: any()) -> any().
normalize_and_sort_non_object({Key, Val}) ->
  {Key, normalize_and_sort_check_object(Val)};
normalize_and_sort_non_object(Value) when is_list(Value) ->
  [normalize_and_sort_check_object(X) || X <- Value];
normalize_and_sort_non_object(Value) when is_number(Value) ->
  float(Value);
normalize_and_sort_non_object(Value) ->
  Value.

%% This function runs the normalization/ordering over the properties
%% of a JSON object. If the object is not formatted as a list (e.g. a
%% map), it is unwrapped into a list. Then the list of properties is
%% order so that its original odering is not relevant, and we run
%% the normalization/ordering through each of the properties.
%% @private
-spec normalize_and_sort_object(Value :: any()) -> any().
normalize_and_sort_object(Value) when is_list(Value) ->
  {struct, lists:sort([normalize_and_sort_check_object(X) || X <- Value])};
normalize_and_sort_object(Value) ->
  normalize_and_sort_object(jesse_json_path:unwrap_value(Value)).

%%=============================================================================
%% @doc Returns `true' if given values (instance) are equal, otherwise `false'
%% is returned.
%%
%% Two instance are consider equal if they are both of the same type
%% and:
%% <ul>
%%   <li>are null; or</li>
%%
%%   <li>are booleans/numbers/strings and have the same value; or</li>
%%
%%   <li>are arrays, contains the same number of items, and each item in
%%       the array is equal to the corresponding item in the other array;
%%       or</li>
%%
%%   <li>are objects, contains the same property names, and each property
%%       in the object is equal to the corresponding property in the other
%%       object.</li>
%% </ul>
-spec is_equal(Value1 :: any(), Value2 :: any()) -> boolean().
is_equal(Value1, Value2) ->
  case jesse_lib:is_json_object(Value1)
    andalso jesse_lib:is_json_object(Value2) of
    true  -> compare_objects(Value1, Value2);
    false -> case is_list(Value1) andalso is_list(Value2) of
               true  -> compare_lists(Value1, Value2);
               false -> Value1 == Value2
             end
  end.

%% @private
compare_lists(Value1, Value2) ->
  case length(Value1) =:= length(Value2) of
    true  -> compare_elements(Value1, Value2);
    false -> false
  end.

%% @private
compare_elements(Value1, Value2) ->
  lists:all( fun({Element1, Element2}) ->
                 is_equal(Element1, Element2)
             end
           , lists:zip(Value1, Value2)
           ).

%% @private
compare_objects(Value1, Value2) ->
  case length(unwrap(Value1)) =:= length(unwrap(Value2)) of
    true  -> compare_properties(Value1, Value2);
    false -> false
  end.

%% @private
compare_properties(Value1, Value2) ->
  lists:all( fun({PropertyName1, PropertyValue1}) ->
                 case get_value(PropertyName1, Value2) of
                   ?not_found     -> false;
                   PropertyValue2 -> is_equal(PropertyValue1,
                                              PropertyValue2)
                 end
             end
           , unwrap(Value1)
           ).

%%=============================================================================
%% Wrappers
%% @private
get_value(Key, Schema) ->
  jesse_json_path:value(Key, Schema, ?not_found).

%% @private
unwrap(Value) ->
  jesse_json_path:unwrap_value(Value).
