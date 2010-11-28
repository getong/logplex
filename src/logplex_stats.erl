-module(logplex_stats).
-behaviour(gen_server).

%% gen_server callbacks
-export([start_link/0, init/1, handle_call/3, handle_cast/2, 
	     handle_info/2, terminate/2, code_change/3]).

-export([healthcheck/0, incr/1, incr/2, flush/0]).

-include_lib("logplex.hrl").

%% API functions
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

healthcheck() ->
    redis_helper:healthcheck().

incr(ChannelId) when is_binary(ChannelId) ->
    case (catch ets:update_counter(logplex_stats_channels, ChannelId, 1)) of
        {'EXIT', _} ->
            ets:insert(logplex_stats_channels, {ChannelId, 0}),
            incr(ChannelId);
        Res ->
            Res
    end;

incr(Key) when is_atom(Key) ->
    incr(Key, 1).

incr(Key, Inc) when is_atom(Key), is_integer(Inc) ->
    ets:update_counter(?MODULE, Key, Inc).


%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%% @hidden
%%--------------------------------------------------------------------
init([]) ->
    ets:new(?MODULE, [public, named_table, set]),
    ets:new(logplex_stats_channels, [public, named_table, set]),
    ets:insert(?MODULE, {message_processed, 0}),
    ets:insert(?MODULE, {session_accessed, 0}),
    ets:insert(?MODULE, {session_tailed, 0}),
    ets:insert(?MODULE, {message_routed, 0}),
    ets:insert(?MODULE, {message_received, 0}),
    ets:insert(?MODULE, {message_dropped1, 0}),
    ets:insert(?MODULE, {message_dropped2, 0}),
    spawn_link(fun flush/0),
	{ok, []}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%% @hidden
%%--------------------------------------------------------------------
handle_call(_Msg, _From, State) ->
    {reply, {error, invalid_call}, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%% @hidden
%%--------------------------------------------------------------------
handle_cast(flush, State) ->
    [begin
        ets:update_element(?MODULE, Key, {2, 0}),
        io:format("logplex_stats ~p=~w~n", [Key, Val])
    end || {Key, Val} <- ets:tab2list(?MODULE)],
    [begin
        ets:update_element(logplex_stats_channels, Key, {2, 0})
    end || {Key, _Val} <- ets:tab2list(logplex_stats_channels)],
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%% @hidden
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%% @hidden
%%--------------------------------------------------------------------
terminate(_Reason, _State) -> 
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%% @hidden
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
flush() ->
    timer:sleep(60 * 1000),
    gen_server:cast(?MODULE, flush),
    flush().