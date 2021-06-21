defmodule TaskQueue.WorkersSupervisor do
  use GenServer

  ## Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: TaskQueue.WorkersSupervisor)
  end

  ## GenServer Callbacks
  @impl true
  def init(%{num_workers: num_workers}) do
    :global.register_name(:workers_supervisor_debug, self())
    if num_workers < 1000 do
      free_workers = Enum.map(0..num_workers-1, fn i ->
        {:ok, process} = TaskQueue.Worker.start_link(
          String.to_atom("#{__MODULE__}.#{i}")
        )
        process
      end)

      {:ok, {free_workers, %{}, :queue.new, %{}, %{}}}
    else
      {:error, "Max 1000 workers"}
    end
  end


  def ending(process, task_id,
             free_workers, busy_workers, queue, tasks_workers, to_cancel) do
    case :queue.is_empty(queue) do
      true -> {:reply, :ok,
        {[process | free_workers],
         Map.delete(busy_workers, task_id),
         queue,
         Map.delete(tasks_workers, task_id),
         to_cancel}
      }
      false ->
        {newstart_infos, newtask_id, newend_infos} = :queue.head(queue)
        if Map.get(to_cancel, newtask_id) == nil do
          GenServer.cast(process, %{start_infos: newstart_infos,
                                    task_id: newtask_id,
                                    end_infos: newend_infos})
          tasks_workers = Map.delete(tasks_workers, task_id)
          busy_workers = Map.delete(busy_workers, task_id)
          {:reply, :ok,
            {free_workers,
             Map.put(busy_workers, newtask_id, process),
             :queue.drop(queue),
             Map.put(tasks_workers, newtask_id, process),
             to_cancel}}
        else
          queue = :queue.drop(queue)
          ending(process, task_id,
                 free_workers, busy_workers, queue,
                 Map.delete(tasks_workers, newtask_id),
                 Map.delete(to_cancel, newtask_id))
        end
    end
  end

  @impl true
  def handle_call(%{clean: task_id}, _from,
                  {free_workers, busy_workers,
                    queue, tasks_workers, to_cancel}) do
    process = Map.get(busy_workers, task_id)
    ending(process, task_id,
           free_workers, busy_workers, queue, tasks_workers, to_cancel)
  end

  @impl true
  def handle_call(%{start_infos: start_infos, task_id: task_id,
                  end_infos: end_infos}, _from,
                  {free_workers, busy_workers,
                    queue, tasks_workers, to_cancel}) do
    tmp = Map.get(tasks_workers, task_id)
    if tmp == nil do
      case free_workers do
        [] ->
          {:reply, task_id, {free_workers,
                             busy_workers,
                             :queue.in({start_infos, task_id, end_infos}, queue),
                             Map.put(tasks_workers, task_id,
                                     %{pending: end_infos}),
                             to_cancel}}
        [process | tail] ->
          GenServer.cast(process, %{start_infos: start_infos, task_id: task_id,
                                    end_infos: end_infos})
          {:reply, task_id, {tail,
                             Map.put(busy_workers, task_id, process),
                             queue,
                             Map.put(tasks_workers, task_id, process),
                             to_cancel}}
      end
    else
      {:reply, "id already used", {free_workers,
                                   busy_workers,
                                   queue,
                                   tasks_workers,
                                   to_cancel}}
    end
  end

  @impl true
  def handle_call(%{cancel: cancel, task_id: task_id}, _from,
                  {free_workers, busy_workers, queue,
                    tasks_workers, to_cancel}) do
    case Map.get(tasks_workers, task_id) do
      %{pending: end_infos} ->
        if end_infos != nil do
          %{module: module, function: function, params: params} = end_infos
          spawn fn ->
            apply(module, function, params ++ [%{result: nil, timeout: false}])
          end
        end
        {:reply, :ok,
        {free_workers, busy_workers, queue,
          tasks_workers, Map.put(to_cancel, task_id, :to_cancel)}}
      nil -> {:reply, :no_task,
        {free_workers, busy_workers, queue, tasks_workers, to_cancel}
      }
      process ->
        GenServer.cast(process, %{cancel: cancel, task_id: task_id})
        {:reply, :ok,
          {free_workers, busy_workers, queue, tasks_workers, to_cancel}}
    end
  end

  @impl true
  def handle_call(%{kill: task_id},
                  _from,
                  {free_workers, busy_workers,
                    queue, tasks_workers, to_cancel}) do
    case Map.get(tasks_workers, task_id) do
      %{pending: end_infos} ->
        if end_infos != nil do
          %{module: module, function: function, params: params} = end_infos
          spawn fn ->
            apply(module, function, params ++ [%{result: nil, timeout: false}])
          end
        end
        {:reply, :ok,
        {free_workers, busy_workers, queue,
          tasks_workers, Map.put(to_cancel, task_id, :to_cancel)}}
      nil -> {:reply, :no_task,
        {free_workers, busy_workers, queue, tasks_workers, to_cancel}
      }
      process ->
        GenServer.cast(process, %{kill: task_id})
        {:reply, :ok,
          {free_workers, busy_workers, queue, tasks_workers, to_cancel}}
    end
  end

end
