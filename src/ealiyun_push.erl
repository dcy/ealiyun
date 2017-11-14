-module(ealiyun_push).
-export([message_to_android/3, message_to_android/6]).

-include_lib("eutil/include/eutil.hrl").

message_to_android(DeviceId, Title, Body) ->
    PushConf = get_push_conf(),
    #{app_key := AppKey, access_key_id := AccessKeyId, access_key_secret := AccessKeySecret} = PushConf,
    message_to_android(AppKey, AccessKeyId, AccessKeySecret, DeviceId, Title, Body).

message_to_android(AppKey, AccessKeyId, AccessKeySecret, DeviceId, Title, Body) ->
    Args = [{"Action", "PushMessageToAndroid"}, {"AppKey", AppKey}, {"Target", "DEVICE"},
            {"TargetValue", DeviceId}, {"Title", Title}, {"Body", Body}
           ],
    AllArgs = lists:sort(Args ++ gen_common_args(AccessKeyId)),
    AllArgsEncoded = eutil:urlencode(AllArgs),
    %StringToSign = "GET" ++ "&" ++ binary_to_list(hackney_url:urlencode("/")) ++ "&" ++ binary_to_list(hackney_url:urlencode(AllArgsEncoded)),
    StringToSign = "GET" ++ "&" ++ http_uri:encode("/") ++ "&" ++ http_uri:encode(AllArgsEncoded),
    Hash = crypto:hmac(sha, AccessKeySecret ++ "&", StringToSign),
    Signature = binary_to_list(base64:encode(Hash)),
    SignArgs = [{"Signature", Signature} | AllArgs],
    QueryArgs = eutil:urlencode(SignArgs),
    URL = "http://cloudpush.aliyuncs.com/?" ++ QueryArgs,
    {ok, _StatusCode, _RespHeaders, ClientRef} = hackney:request(get, URL, [],
                                                                 <<>>, []),
    {ok, ResultBin} = hackney:body(ClientRef),
    Result = eutil:json_decode(ResultBin),
    case Result of
        #{<<"MessageId">> := _, <<"RequestId">> := _} ->
            {ok, Result};
        #{<<"Code">> := Code, <<"Message">> := Message} ->
            lager:error("ealiyun_push error, DeviceId: ~p, Code: ~p, Message: ~p", [DeviceId, Code, Message]),
            {error, Result}
    end.




get_push_conf() ->
    {ok, PushConf} = application:get_env(ealiyun, push),
    PushConf.

%%不包含Signature
gen_common_args(KeyId) ->
    Timestamp = binary_to_list(eutil:utc_string()),
    [{"Format", "JSON"}, {"RegionId", "cn-hangzhou"}, {"Version", "2016-08-01"}, {"AccessKeyId", KeyId},
     {"SignatureMethod", "HMAC-SHA1"}, {"Timestamp", Timestamp}, {"SignatureVersion", "1.0"},
     {"SignatureNonce", rand:uniform(10000)}
    ].
