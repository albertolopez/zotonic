%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% Date: 2009-04-27
%% @doc Open a dialog with some fields to make a new page/resource.

%% Copyright 2009 Marc Worrell
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

-module(action_admin_dialog_new_rsc).
-author("Marc Worrell <marc@worrell.nl").

%% interface functions
-export([
    render_action/4,
    event/2
]).

-include("zotonic.hrl").

render_action(TriggerId, TargetId, Args, Context) ->
    Cat = proplists:get_value(cat, Args),
    NoCatSelect = z_convert:to_bool(proplists:get_value(nocatselect, Args, false)),
    Title = proplists:get_value(title, Args),
    Redirect = proplists:get_value(redirect, Args, true),
    SubjectId = proplists:get_value(subject_id, Args),
    Predicate = proplists:get_value(predicate, Args),
    Callback = proplists:get_value(callback, Args),
    Actions = proplists:get_all_values(action, Args),
    Postback = {new_rsc_dialog, Title, Cat, NoCatSelect, Redirect, SubjectId, Predicate, Callback, Actions},
    {PostbackMsgJS, _PickledPostback} = z_render:make_postback(Postback, click, TriggerId, TargetId, ?MODULE, Context),
    {PostbackMsgJS, Context}.


%% @doc Fill the dialog with the new page form. The form will be posted back to this module.
%% @spec event(Event, Context1) -> Context2
event(#postback{message={new_rsc_dialog, Title, Cat, NoCatSelect, Redirect, SubjectId, Predicate, Callback, Actions}}, Context) ->
    CatName = case Cat of
        undefined -> z_convert:to_list(?__("page", Context));
        _ -> z_convert:to_list(?__(m_rsc:p(Cat, title, Context), Context))
    end,
    CatId = case Cat of
                undefined -> undefined;
                X when is_integer(X) -> X;
                X -> m_category:name_to_id_check(X, Context)
            end,
    Vars = [
        {delegate, atom_to_list(?MODULE)},
        {redirect, Redirect },
        {subject_id, SubjectId},
        {predicate, Predicate},
        {title, Title},
        {cat, CatId},
        {nocatselect, NoCatSelect},
        {catname, CatName},
        {callback, Callback},
        {catname, CatName},
        {actions, Actions}
    ],
    z_render:dialog(z_convert:to_list(?__("Make a new ", Context))++CatName, "_action_dialog_new_rsc.tpl", Vars, Context);


event(#submit{message={new_page, Args}}, Context) ->
    Redirect = proplists:get_value(redirect, Args),
    SubjectId = proplists:get_value(subject_id, Args),
    Predicate = proplists:get_value(predicate, Args),
    Callback = proplists:get_value(callback, Args),
    Actions = proplists:get_value(actions, Args, []),

    BaseProps = get_base_props(z_context:get_q("new_rsc_title", Context), Context),
    {ok, Id} = m_rsc_update:insert(BaseProps, Context),

    % Optionally add an edge from the subject to this new resource
    {_,Context1} = mod_admin:do_link(z_convert:to_integer(SubjectId), Predicate, Id, Callback, Context),

    % Close the dialog
    Context2a = z_render:wire({dialog_close, []}, Context1),

    % wire any custom actions
    Context2 = z_render:wire([{Action, [{id, Id}|ActionArgs]}|| {Action, ActionArgs} <- Actions], Context2a),

    % optionally redirect to the edit page of the new resource
    case z_convert:to_bool(Redirect) of
        false ->
             Context2;
        true ->
            Location = z_dispatcher:url_for(admin_edit_rsc, [{id, Id}], Context2),
            z_render:wire({redirect, [{location, Location}]}, Context2)
    end.

get_base_props(undefined, Context) ->
    z_context:get_q_all_noz(Context);
get_base_props(NewRscTitle, Context) ->
    Lang = z_context:language(Context),
    CatId = list_to_integer(z_context:get_q("category_id", Context)),
    IsPublished = z_context:get_q("is_published", Context),
    Name = z_context:get_q("name", Context),
    [
        {title, {trans, [{Lang, NewRscTitle}]}},
        {language, [Lang]},
        {name, Name},
        {category_id, CatId},
        {is_published, IsPublished}
    ].

