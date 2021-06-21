# Purpose
A task queue in Elixir.

# Usage

## Initialization
Call `TaskQueue.WorkersSupervisor.init(num_workers)` to initialize the queue with
`num_workers` workers.

## Start a task
Each task is given by:
  * A task_id
  * A function to execute when a task starts
  * A list of parameters for this function
  * A timeout (`nil` means no timetout)
  * A function that will be called when the task ends
  * A list of parameters for this function

WARNING : the function to execute when a task ends MUST take one additional parameters
          of the form `%{result: result, timeout: has_timeouted}` which
          gives the function result and indicates whether the execution
          terminated because of a timeout.

Call
````iex
GenServer.call(TaskQueue.WorkersSupervisor, %{
    start_infos: %{module: <the start function module>,
                   function: :start_fct_name,
                   params: <the list of params>,
                   timeout: <the timetout>},
    task_id: task_id,
    end_infos: %{module: TaskQueue.WorkersSupervisor,
                 function: :end_fct_name,
                 params: end_params}
  }
)
````
to start a task.

## Kill a task
Call
````iex
GenServer.call(TaskQueue.WorkersSupervisor, %{kill: task_id})
````
To kill the task with id `task_id`.

If the task is still in the queue it will not be executed and the function
given in `:end_infos` will be directly executed when the task turn comes.

If the task is running it will be killed immediately and the function
given in `:end_infos` will be directly executed.


## Cancel a task
Call
````iex
GenServer.call(TaskQueue.WorkersSupervisor, %{
  cancel: %{module: <the cancel function module>,
            function: :cancel_fct_name,
            params: <the list of params>}, task_id: task_id
})
````
To cancel the task with id `task_id`.

If the task is still in the queue it will not be executed and the function
given in `:end_infos` will be directly executed when the task turn comes.

If the task is running, the function `cancel_fct_name` will be called
(and nothing more). The function is meant to gently kill the task.
