defmodule Chat do
  def start do
    {host, port} = get_host_and_port()
    options = [mode: :binary, active: true, packet: 2]

    case :gen_tcp.connect(String.to_charlist(host), port, options) do
      {:ok, socket} ->
        nickname = String.trim(IO.gets("Nickname: "))
        spawn_gets_process(nickname)
        loop(socket, nickname)

      {:error, reason} ->
        raise "Cannot connect to specified address: #{inspect(reason)}"
    end
  end

  defp spawn_gets_process(nickname) do
    parent = self()

    spawn(fn ->
      message = String.trim(IO.gets("#{nickname}: "))
      send(parent, {:gets, message})
    end)
  end

  defp loop(socket, nickname) do
    receive do
      {:gets, message} ->
        payload = %{"kind" => "broadcast", "nickname" => nickname, "message" => message}
        :ok = :gen_tcp.send(socket, Jason.encode!(payload))
        spawn_gets_process(nickname)
        loop(socket, nickname)

      {:tcp, ^socket, data} ->
        data
        |> Jason.decode!()
        |> handle_message(nickname)

        loop(socket, nickname)

      {:tcp_closed, ^socket} ->
        raise "TCP connected was closed"

      {:tcp_error, ^socket, error} ->
        raise "TCP connection error: #{inspect(error)}"
    end
  end

  defp handle_message(%{"kind" => "welcome", "users_online" => num_users}, _nickname) do
    case num_users do
      0 -> IO.puts("Welcome to the ElixirConf server, there are no users online.")
      1 -> IO.puts("Welcome to the ElixirConf server, there is 1 user online.")
      Integer -> IO.puts("Welcome to the ElixirConf server, there are #{num_users} users online.")
      _ -> IO.puts("Welcome to the ElixirConf server")
    end
  end

  defp handle_message(
         %{
           "kind" => "broadcast",
           "nickname" => my_nickname,
           "message" => _message
         },
         my_nickname
       ) do
  end

  defp handle_message(
         %{
           "kind" => "broadcast",
           "nickname" => nickname,
           "message" => message
         },
         _nickname
       ) do
    IO.puts("#{nickname}: #{message}")
  end

  defp handle_message(_nickname, _unknown_message) do
    IO.puts("Unrecognized message received")
  end

  defp get_host_and_port do
    address = String.trim(IO.gets("Server address: "))

    case address do
      "" ->
        {"localhost", 4000}

      _ ->
        [host, port] = String.split(address, ":")
        port = String.to_integer(port)
        {host, port}
    end
  end
end
