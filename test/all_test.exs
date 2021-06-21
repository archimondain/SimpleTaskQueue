defmodule TaskQueue.Test do
  use ExUnit.Case

  def help_begin(num_workers) do
    TaskQueue.WorkersSupervisor.start_link(%{num_workers: num_workers})
    ref = make_ref()
    pid = self()

    callback = fn() ->
      send(pid, ref)
    end
    {ref, callback}
  end

  def help_end(ref) do
    receive do
      ^ref -> :ok
    end
    pid = :global.whereis_name(:workers_supervisor_debug)
    :timer.sleep(100)
    {free_workers, busy_workers, queue, tasks_workers, to_cancel} =
      :sys.get_state(pid)
    assert length(free_workers) == 4 and map_size(busy_workers) == 0
    assert :queue.is_empty(queue) and map_size(tasks_workers) == 0
    assert map_size(to_cancel) == 0
    GenServer.stop(TaskQueue.WorkersSupervisor, :normal)
  end

  test "basic10_worker1" do
    {ref, callback} = help_begin(4)
    num = 10
    GenServer.call(TaskQueue.SynchronizeResults,
                   %{goal: num, callback: callback})
    TaskQueue.TestHelper.massive_call(num, 1)
    help_end(ref)
  end

  test "basic10_worker4" do
    {ref, callback} = help_begin(4)
    num = 10
    GenServer.call(TaskQueue.SynchronizeResults,
                   %{goal: num, callback: callback})
    TaskQueue.TestHelper.massive_call(num, 1)
    help_end(ref)
  end

  test "basic100_worker4" do
    {ref, callback} = help_begin(4)
    num = 100
    GenServer.call(TaskQueue.SynchronizeResults,
                   %{goal: num, callback: callback})
    TaskQueue.TestHelper.massive_call(num, 1)
    help_end(ref)
  end

  test "timeout10_worker4" do
    {ref, callback} = help_begin(4)
    num = 10
    GenServer.call(TaskQueue.SynchronizeResults,
                   %{goal: num, callback: callback})
    TaskQueue.TestHelper.massive_call(num, 1000, 1)
    help_end(ref)
  end

  test "kill10_worker4" do
    {ref, callback} = help_begin(4)
    num = 10
    GenServer.call(TaskQueue.SynchronizeResults,
                   %{goal: num, callback: callback})
    TaskQueue.TestHelper.massive_call(num, 1000)
    TaskQueue.TestHelper.massive_kill(1,10)
    help_end(ref)
  end

  test "kill1000_worker4" do
    {ref, callback} = help_begin(4)
    num = 1000
    GenServer.call(TaskQueue.SynchronizeResults,
                   %{goal: num, callback: callback})
    TaskQueue.TestHelper.massive_call(num, 1)
    TaskQueue.TestHelper.massive_kill(100,900)
    help_end(ref)
  end

  test "cancel10_worker4" do
    {ref, callback} = help_begin(4)
    num = 10
    GenServer.call(TaskQueue.SynchronizeResults,
                   %{goal: num, callback: callback})
    TaskQueue.TestHelper.massive_call(num, 1)
    TaskQueue.TestHelper.massive_cancel(1,10)
    help_end(ref)
  end
end
