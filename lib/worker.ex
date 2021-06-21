defmodule TaskQueue.Worker do
  use GenServer

  ## Client API
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  ## GenServer Callbacks
  @impl true
  def init(:ok) do
    Process.flag(:trap_exit, true)
    {:ok, %{task_id: nil, pid: nil, end_infos: nil, result: nil,
            timeout_infos: %{has_timeouted: false, timer: nil}}}
  end

  @impl true
  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(%{cancel: cancel, task_id: task_idc},
                  %{task_id: task_id, pid: pid, end_infos: end_infos,
                    result: result, timeout_infos: timeout_infos}) do
    if task_id == task_idc and cancel != nil do
      %{module: module, function: function, params: params} = cancel
      apply(module, function, params)
    end
    {:noreply, %{task_id: task_id, pid: pid, end_infos: end_infos,
                 result: result, timeout_infos: timeout_infos}}
  end

  @impl true
  def handle_cast(%{kill: task_idk},
                  %{task_id: task_id, pid: pid, end_infos: end_infos,
                    result: result, timeout_infos: timeout_infos}) do
    if task_id == task_idk do
      Process.exit(pid, :kill)
    end
    {:noreply, %{task_id: task_id, pid: pid, end_infos: end_infos,
                 result: result, timeout_infos: timeout_infos}}
  end

  @defaults %{timeout: nil}
  @impl true
  def handle_cast(%{start_infos: task, task_id: task_idc,
                    end_infos: end_infos}, _state) do
    %{module: module, function: function, params: params, timeout: timeout} =
      Map.merge(@defaults, task)
    mytask = Task.async(fn -> apply(module, function, params) end)
    ntimer =
      if timeout != nil do
        Process.send_after(self(), :timeout, timeout)
      else
        nil
      end
    {:noreply, %{task_id: task_idc, pid: mytask.pid,
                 end_infos: end_infos, result: nil,
                 timeout_infos: %{has_timeouted: false, timer: ntimer}}}
  end


  @impl true
  def handle_info(:timeout,
                  %{task_id: task_id, pid: pid, end_infos: end_infos,
                    result: result, timeout_infos: timeout_infos}) do
    %{has_timeouted: _has_timeouted, timer: timer} = timeout_infos
    Process.exit(pid, :kill)
    {:noreply, %{task_id: task_id, pid: pid,
                 end_infos: end_infos, result: result,
                 timeout_infos: %{has_timeouted: true, timer: timer}}}
  end

  @impl true
  def handle_info({_ref, result},
                  %{task_id: task_id, pid: pid, end_infos: end_infos,
                    result: _result, timeout_infos: timeout_infos}) do
    {:noreply, %{task_id: task_id, pid: pid,
                 end_infos: end_infos, result: result,
                 timeout_infos: timeout_infos}}
  end

  # Once the task finised successfully, it exits normally.
  # This handle_info function responds to this message.
  def handle_info({:EXIT, _pid, _reason}, state) do
     {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _object, _reason},
                  %{task_id: task_id, pid: _pid, end_infos: end_infos,
                    result: result, timeout_infos: timeout_infos}) do
    %{has_timeouted: has_timeouted, timer: timer} = timeout_infos
    if timer != nil do
      Process.cancel_timer(timer)
    end
    if end_infos != nil do
      %{module: module, function: function, params: params} = end_infos
      apply(module, function,
            params ++ [%{result: result, timeout: has_timeouted}])
    end
    GenServer.call(TaskQueue.WorkersSupervisor, %{clean: task_id})
    {:noreply, %{task_id: nil, pid: nil, end_infos: nil, result: nil,
                 timeout_infos: %{has_timeouted: false, timer: nil}}}
  end
end
