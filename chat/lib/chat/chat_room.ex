defmodule ChatRoom do
  use GenServer
  require Logger

  @doc """
  Start the chat room server, with initial state of an empty list of clients
  """
  def start_link() do
    GenServer.start_link(__MODULE__, [], [{:name, __MODULE__}])
  end

  @doc """
  Initialize the server
  """
  def init(user_list) do
    {:ok, user_list}    
  end

  @doc """
  Reset the server (clear the user list. used to reset the server for tests)
  """
  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  @doc """
  Reset the server synchronously
  """
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, []}
  end

  @doc """
  Adds the user name, server name, and pid (which is in the from parameter)
  to the server’s state. Don’t allow a duplicate user name from the same 
  server. You can use List.keymember?/3 for this. The tuple looks like this:
  {{user, user_server}, pid}
  """
  def handle_call({:login, user_name, user_server}, 
      {pid, _refnum}, user_list) do
    name_string = if is_atom(user_name) do
      to_string(user_name)
    else
      user_name
    end
    if !List.keymember?(user_list, user = {name_string, user_server}, 0) do
      {:reply, :ok, [{user, pid}|user_list]}
    else
      Logger.info(
        "Duplicate user/server combination: #{name_string}@#{user_server}")
      {:reply, :error, user_list}
    end
  end

  @doc """
  Removes the user from the state list.
  """
  def handle_call(:logout, {pid, _refnum}, user_list) do
    case List.keytake(user_list, pid, 1) do
      nil ->
        Logger.info( 
            "No user with pid: #{pid} found")
        {:reply, :error, user_list}
      {{{user_name, user_server}, _pid}, new_user_list} ->
        Logger.info(
            "User #{user_name}@#{user_server} logged out of chat room")
        {:reply, :ok, new_user_list}
    end
  end

  @doc """
  Sends the given text to all the other users in the chat room. Use 
  GenServer.cast/2 to send the message to each user. You may use a 
  process id as the first argument to GenServer.cast/2.
  """
  def handle_call({:say, text}, {pid, _refnum}, user_list) do
    {sender, _}  = List.keyfind(user_list, pid, 1)
    Enum.each(user_list, fn({_user, pid}) ->
        GenServer.cast(pid, {:message, sender, text}) end)
    {:reply, :ok, user_list}
  end

  @doc """
  Returns the list of names and servers for all people currently in 
  the chat room.
  """
  def handle_call(:users, _from, user_list) do
    {:reply, Enum.map(user_list, fn({user, _pid}) -> user end), user_list}
  end

  @doc """
  Return the profile of the given person/server. (This is "extra credit"; 
  see the following details about the Person module). It works by finding
  the pid of person at node server_name and sending it a :get_profile
  request.
  """
  def handle_call({:profile, person, server}, _from, user_list) do
    case List.keyfind(user_list, {person, server}, 0) do
      nil -> 
        Logger.info("User #{person}@#{server} not found")
        {:reply, :error, user_list}
      {_user, user_pid} ->
        {:reply, GenServer.call(user_pid, :profile), user_list}
    end
  end

end
