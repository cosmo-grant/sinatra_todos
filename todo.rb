require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list) 
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
    
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# view list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# show todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# return an error message if name is invalid, else nil
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "The list name must be unique."
  end
end

# return an error message if name is invalid, else nil
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  end
end

# create new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# update an existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error  
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# delete a todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# add a todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# delete a todo from a list
post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  session[:lists][@list_id][:todos].delete_at(todo_id)
  session[:success] = "The todo was deleted."
  redirect "/lists/#{@list_id}"
end

# update todo status
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  todo = session[:lists][@list_id][:todos][todo_id]

  is_completed = params[:completed] == "true"
  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# complete all todos on list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  todos = session[:lists][@list_id][:todos]
  todos.each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end