require Logger

ExUnit.start()

defmodule TaskQueue.SynchronizeResults do
  use GenServer

  ## Client API
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: TaskQueue.SynchronizeResults)
  end

  @impl true
  def init(_args) do
    {:ok, %{nb: 0, goal: 0, callback: nil}}
  end

  @impl true
  def handle_call(%{goal: goal, callback: callback}, _from, _state) do
    {:reply, :ok, %{nb: 0, goal: goal, callback: callback}}
  end


  @impl true
  def handle_call(nil, _from,
                  %{nb: nb, goal: goal, callback: callback}) do
    if nb+1 >= goal do
      callback.()
      {:reply, :ok, %{nb: 0, goal: 0, callback: nil}}
    else
      {:reply, :ok, %{nb: nb+1, goal: goal, callback: callback}}
    end
  end
end

defmodule TaskQueue.TestHelper do

  def test_start_fct1(time) do
    :timer.sleep(time)
  end

  def test_cancel_fct1() do
    nil
  end

  def test_end_fct1(num, %{result: _res, timeout: _has_timeouted}) do
    Logger.debug "debugging #{num}"
    GenServer.call(TaskQueue.SynchronizeResults, nil)
  end

  def massive_call(num, time, timeout \\ nil) do
    0..num-1
    |> Enum.each(fn x -> GenServer.call(TaskQueue.WorkersSupervisor,
      %{start_infos: %{module: TaskQueue.TestHelper, function: :test_start_fct1, params: [time], timeout: timeout},
        task_id: x,
        end_infos: %{module: TaskQueue.TestHelper, function: :test_end_fct1, params: [x]}}
    ) end)
  end

  def massive_kill(num_start, num_end) do
    num_start-1..num_end-1
    |> Enum.each(fn x -> GenServer.call(TaskQueue.WorkersSupervisor, %{kill: x}) end)
  end

  def massive_cancel(num_start, num_end) do
    num_start-1..num_end-1
    |> Enum.each(fn x -> GenServer.call(TaskQueue.WorkersSupervisor,
      %{cancel: %{module: TaskQueue.TestHelper, function: :test_cancel_fct1, params: []}, task_id: x}
    ) end)
  end
end

TaskQueue.SynchronizeResults.start_link(nil)
