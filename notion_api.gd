extends Node

const API_URL = "https://api.notion.com/v1"
const PAGES_ENDPOINT = "/pages"
const DB_ENDPOINT = "/databases"
const SEARCH_ENDPOINT = "/search"

const ACTION_DB_TITLE = "Action Database"
const REWARDS_DB_TITLE = "Rewards"
const EXP_REWARDS_DB_TITLE = "Exp. Rewards"

signal updated_actions_to_collect
signal all_actions_collected
signal reward_updated
signal logged_in

var headers: Array[String]
var is_logged_in: bool:
	get: return headers.size() > 0

var actions_to_collect: Array[Dictionary]
var start_date: String
var end_date: String
var reward_database_id: String
var actions_database_id: String
var exp_reward_database_id: String

func login(secret: String) -> bool:
	headers = [
		"Authorization: Bearer " + secret,
		"Content-Type: application/json",
		"Notion-Version: 2022-06-28"
	]
	var data = {
		"query": "action rewards",
		"filter": {
			"value": "database",
			"property": "object"
		}
	}
	var json_string = JSON.stringify(data)
	var url := API_URL + SEARCH_ENDPOINT
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	var params = await http.request_completed
	if params[0] != HTTPRequest.RESULT_SUCCESS or params[1] != 200:
		printerr("Can't Login")
		headers = []
		return false
	var json = JSON.parse_string(params[3].get_string_from_utf8())
	var results = json["results"]
	for db in results:
		if db["title"][0]["plain_text"] == ACTION_DB_TITLE:
			actions_database_id = db["id"]
		elif db["title"][0]["plain_text"] == REWARDS_DB_TITLE:
			reward_database_id = db["id"]
		elif db["title"][0]["plain_text"] == EXP_REWARDS_DB_TITLE:
			exp_reward_database_id = db["id"]
	
	if actions_database_id == null or \
			reward_database_id == null or \
			exp_reward_database_id == null:
		printerr("Something is wrong with Notion template")
		headers = []
		return false
	http.queue_free()
	logged_in.emit()
	return true

func update_actions_to_collect() -> void:
	var data := {
		"filter": {
			"and": [
				{
					"property" : "Completed",
					"checkbox" : {
						"equals" : true
					}
				},
				{
					"property" : "Collected",
					"checkbox" : {
						"equals" : false
					}
				},
			]
		}
	}
	
	var json = JSON.stringify(data)
	var http := HTTPRequest.new()
	add_child(http)
	var url = API_URL + DB_ENDPOINT + "/"  + actions_database_id + "/query"
	http.request_completed.connect(_on_request_completed.bind(http))
	http.request(url, headers, HTTPClient.METHOD_POST, json)

func _on_request_completed(result, response_code, headers, body: PackedByteArray, http: HTTPRequest):
	var json = JSON.parse_string(body.get_string_from_utf8())
	
	var results := json["results"] as Array
	if results.size() == 0:
		print("No actions to collect")
		updated_actions_to_collect.emit()
		return
	
	start_date = results[0]["properties"]["Start of Week"]["rollup"]["array"][0]["formula"]["date"]["start"]
	var start_date_dict := Time.get_datetime_dict_from_datetime_string(start_date, false)
	var start_date_fmt = str(start_date_dict["year"]) + "/" + str(start_date_dict["month"]) + "/" + str(start_date_dict["day"])
	end_date = results[0]["properties"]["End of Week"]["rollup"]["array"][0]["formula"]["date"]["start"]
	var end_date_dict := Time.get_datetime_dict_from_datetime_string(end_date, false)
	var end_date_fmt = str(end_date_dict["year"]) + "/" + str(end_date_dict["month"]) + "/" + str(end_date_dict["day"])
	print("Period: " + start_date_fmt + "-> " + end_date_fmt)
	
	var total_coins = 0
	var total_bonus = 0
	actions_to_collect.clear()
	
	for r in results:
		var action := {
			"id": r["id"],
			"coins": r["properties"]["Total Value (coins)"]["formula"]["number"],
			"type": r["properties"]["Action Type"]["select"]["name"],
			"name": r["properties"]["Name"]["title"][0]["text"]["content"]
		}
		
		var weekly_completed: bool = r["properties"]["WeeklyCompleted"]["formula"]["boolean"]
		if weekly_completed:
			action["habit_bonus"] = r["properties"]["# Value"]["formula"]["number"]
		else:
			action["habit_bonus"] = 0
		actions_to_collect.append(action)
		
		printt(action["name"], 
			" | " + action["type"],
			" | " + str(action["coins"]) + " Coins",
			" | " + str(action["habit_bonus"]) + " Bonus"
		)
		total_coins += action["coins"]
		total_bonus += action["habit_bonus"]
	
	print("Total Coins: " + str(total_coins))
	print("Total Bonus: " + str(total_bonus))
	http.queue_free()
	updated_actions_to_collect.emit()

func collect_all_actions() -> void:
	for action in actions_to_collect:
		await collect_action(action)
	all_actions_collected.emit()
	await create_reward()

func collect_action(action: Dictionary):
	var url = API_URL + PAGES_ENDPOINT + "/" + action["id"]
	var http := HTTPRequest.new()
	add_child(http)
	var data = {
		"properties": {
			"Collected": { "checkbox": true }
		}
	}
	print("Collecting action: " + action["name"] + " ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])
	http.queue_free()

func create_reward():
	var this_week_reward := await get_this_week_reward()
	
	if not this_week_reward.is_empty():
		await update_reward(this_week_reward)
	else:
		await create_new_reward()
	reward_updated.emit()

func get_this_week_reward() -> Dictionary:
	var url := API_URL + DB_ENDPOINT + "/" + reward_database_id + "/query"
	var http := HTTPRequest.new()
	add_child(http)
	var data = {
		"filter": {
			"property" : "IsThisWeek",
			"checkbox" : {
				"equals" : true
			}
		}
	}
	var json_string := JSON.stringify(data)
	http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	var params := await http.request_completed as Array
	
	var json := JSON.parse_string(params[3].get_string_from_utf8()) as Dictionary
	var results := json["results"] as Array
	if results.size() > 0:
		return {"id": results[0]["id"], "coins": results[0]["properties"]["Coins"]["number"] }
	else:
		return {}

func update_reward(reward: Dictionary):
	var url = API_URL + PAGES_ENDPOINT + "/" + reward["id"]
	var http := HTTPRequest.new()
	add_child(http)
	var data = {
		"properties": {
			"Coins": { "number": get_total_coins() + get_total_bonus() + reward["coins"] }
		}
	}
	print("Updating reward ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])

func create_new_reward():
	var url = API_URL + PAGES_ENDPOINT
	var http := HTTPRequest.new()
	add_child(http)
	
	var data = {
		"parent": { "database_id": reward_database_id },
		"properties": {
			"Coins": {
				"number": get_total_coins() + get_total_bonus()
			},
			"Period": {
				"date": {
					"start" : start_date,
					"end": end_date,
				}
			}
		}
	}
	
	print("Creating new reward ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])

func get_total_coins() -> int:
	var total_coins := 0
	for action in actions_to_collect:
		total_coins += action["coins"]
	return total_coins

func get_total_bonus() -> int:
	var total_bonus := 0
	for action in actions_to_collect:
		total_bonus += action["habit_bonus"]
	return total_bonus
