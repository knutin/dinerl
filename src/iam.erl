-module(iam).
-author('Valentino Volonghi <valentino@adroll.com>').

-export([get_session_token/2, parse_response/1]).

-include_lib("xmerl/include/xmerl.hrl").

%% returns
%% Result -> [pair()]
%% pair() -> [{token, binary}|{secret_access_key, binary}|{access_key_id, binary}|{expiration, binary}]
get_session_token(AccessKeyId, SecretAccessKey) ->
    Url = token_url(AccessKeyId, SecretAccessKey, "GetSessionToken"),
    case fetch_and_return_url(Url) of
        {ok, Body} ->
            parse_response(Body);
        Error ->
            Error
    end.

token_url(AccessKeyId, SecretAccessKey, Action) ->
    ArgList = [{"Action", Action}, {"Version", "2011-06-15"}],
    Params = awsrequest:add_sign(AccessKeyId, SecretAccessKey, "sts.amazonaws.com", "GET", ArgList),
    "https://sts.amazonaws.com/?" ++ Params.

parse_response(Body) ->
    {Parsed, _Misc} = xmerl_scan:string(Body),
    xmerl_xs:xslapply(fun template/1,
                      xmerl_xs:select("/GetSessionTokenResponse/GetSessionTokenResult/Credentials/*", Parsed)).

template(#xmlElement{name='SessionToken', content=[#xmlText{value=C}]}) ->
    {token, C};
template(#xmlElement{name='SecretAccessKey', content=[#xmlText{value=C}]}) ->
    {secret_access_key, C};
template(#xmlElement{name='AccessKeyId', content=[#xmlText{value=C}]}) ->
    {access_key_id, C};
template(#xmlElement{name='Expiration', content=[#xmlText{value=C}]}) ->
    {expiration, C}.


http_options() ->
    [{timeout, 200000}, {relaxed, true}].

http_client_headers() ->
    [{"Connection", "close"}].

fetch_and_return_url(Url) ->
    case catch(httpc:request(get, {Url, http_client_headers()}, http_options(), [])) of
        {ok, {{_, 200, _}, _Headers, Body}} ->
            {ok, Body};
        Error ->
            Error
    end.
