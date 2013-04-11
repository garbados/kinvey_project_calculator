#= require ext/jquery.min.js
#= require ext/jquery.base64.js
#= require ext/lodash.min.js
#= require ext/handlebars.min.js
#= require ext/backbone.min.js
#= require ext/bootstrap.min.js

## Sweet Kinvey-Backbone helpers courtesy of [Dave Wasmer](https://github.com/Kinvey/backbone-kinvey-todos/blob/master/todos.coffee)

# To access the Kinvey backend, we need to have our app id and master secret
# holy god, why do I need the master secret? Why does the mere app secret return 401?
kinvey_app_key = 'kid_VT0BZOWVdM'
kinvey_master_secret = '30b64a1ae803427188e580ed96567c3c'

# This function adds our Basic Authentication header to Backbone's requests
kinveyAuthenticatedSync = (method, model, options) ->
		auth = 'Basic ' + $.base64.encode(kinvey_app_key + ':' + kinvey_master_secret)
		options.beforeSend = (jqXHR) ->
				jqXHR.setRequestHeader 'Authorization', auth
		Backbone.sync.call(this, method, model, options)

# We create a Model class we can later use for any Kinvey-backed resource
# in our application. It makes sure to add the Basic Auth header and uses
# the `_id` field as the id attribute for the model.
# http://documentcloud.github.com/backbone/#Model-idAttribute
class KinveyModel extends Backbone.Model
		sync: kinveyAuthenticatedSync
		idAttribute: '_id'

# Same with the collection - now, we can use this to represent any collection
# of Kinvey-backed models. [Max: added `url` for extra effortlessness]
class KinveyCollection extends Backbone.Collection
		sync: kinveyAuthenticatedSync
		url: -> "https://baas.kinvey.com/appdata/#{kinvey_app_key}/#{@name}"

## HELPERS

# Feeling lazy, but don't want to drop log messages after `Entity.save`? 
# That's exactly how you feel.
lazy_cb =
	success: ->
		console.log arguments
	error: ->
		console.warn arguments

## MODELS

class Project extends KinveyModel

class Task extends KinveyModel

class Resource extends KinveyModel
	defaults:
		title: "Techlologist"
		cost: "100"
	initialize: (options) ->
		if not @get("title") then @set("title", @defaults.title)
		if not @get("cost") then @set("cost", @defaults.cost)

## COLLECTIONS

class Projects extends KinveyCollection
	name: 'projects'
	model: Project

class Tasks extends KinveyCollection
	name: 'tasks'
	model: Task

class Resources extends KinveyCollection
	name: 'resources'
	model: Resource

## VIEWS

ResourcesView = Backbone.View.extend
	el: "#resources"
	list: @$("#resources .list")
	events:
		# "submit > section > .row > .span5 > .new-resource > form": "addResource"
		"click .submit": "addResource"
	initialize: ->
		@collection.fetch()
		@collection.on('change sync', @render, @)
	render: ->
		@list.empty()
		@collection.each (resource) => @addOne resource
	addOne: (resource) ->
		view = new ResourceView {model: resource}
		@list.append(view.render())
	addResource: (event) ->
		attributes =
			title: @$('[name="title"]').val()
			cost: @$('[name="cost"]').val()
		@collection.create attributes, 
			success: (resource) =>
				@addOne resource
		false

ResourceView = Backbone.View.extend
	id: @model.get('_id')
	events: ->
		"click .delete": "destroy"
		"dblclick .content": "edit"
		"click .submit": "submit"
	template: Handlebars.compile $("#resource-view").html()
	render: ->
		@template @model.toJSON()
	edit: ->
		@$(@el).addClass("editing")
	submit: ->
		attributes =
			title: @$('[name="title"]').val()
			cost: @$('[name="cost"]').val()
		@model.save attributes
		$el.html @template @model.toJSON()
	destroy: ->
		if confirm "Are you sure?"
			@model.destroy()
			@$el.remove()

TasksView = Backbone.View.extend

TaskView = Backbone.View.extend

NewTaskView = Backbone.View.extend

## ROUTER AND START

Router = Backbone.Router.extend
	routes:
		"resources":"showResources"
		"tasks":"showTasks"
	initialize: (options) ->
		@tasksView = new TasksView
			collection: new Tasks()
		@resourcesView = new ResourcesView
			collection: new Resources()
	showResources: ->
		$('.sub-site > li').removeClass('active')
		$('#resourcesLink').addClass('active')
		@resourcesView.render()
	showTasks: ->
		$('.sub-site > li').removeClass('active')
		$('#tasksLink').addClass('active')
		@tasksView.render()

$ ->
	router = new Router()
	Backbone.history.start()
	return