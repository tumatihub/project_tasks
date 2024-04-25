extends Node

const API_URL = "https://api.notion.com/v1"
const PAGES_ENDPOINT = "/pages"
const DB_ENDPOINT = "/databases"
const SEARCH_ENDPOINT = "/search"

const ACTION_DB_TITLE = "Action Database"
const REWARDS_DB_TITLE = "Rewards"
const EXP_REWARDS_DB_TITLE = "Exp. Rewards"
const PROJECT_DB_TITLE = "Project Database"
const OBJECTIVE_DB_TITLE = "Objectives"
const WALLET_DB_TITLE = "Wallet"
const EXP_CALCULATOR_DB_TITLE = "Exp Calculator"
const CALCULATOR_DB_TITLE = "Calculator"

const ACTION_TYPE_HABIT = "Habit"
const PROJECT_SRC_NAME = "Project"
const OBJECTIVE_SRC_NAME = "Objective"

const SAVE_FILE_PATH = "user://notion_state.cfg"

signal updated_actions_to_collect
signal updated_projects_to_collect
signal updated_objectives_to_collect
signal updated_xp_to_collect
signal all_actions_collected
signal all_xp_collected
signal reward_updated
signal logged_in
signal cant_log_in

var headers: Array[String]
var header_secret: String
var is_logged_in: bool = false

var actions_to_collect: Array[Dictionary]
var projects_to_collect: Array[Dictionary]
var objectives_to_collect: Array[Dictionary]
var start_date: String
var end_date: String
var wallet_database_id: String
var reward_database_id: String
var actions_database_id: String
var exp_reward_database_id: String
var exp_calculator_database_id: String
var exp_calculator_id: String
var calculator_database_id: String
var calculator_id: String
var wallet_id: String
var project_src_opt: Dictionary
var objective_src_opt: Dictionary
var projects_database_id: String
var objectives_database_id: String
var collect_habits: bool = false
var pending_coins: int = 0
var exp_rewards: Array[Dictionary] = []

func _ready() -> void:
	load_state()
	print("Header Secret: " + header_secret)
	print("Pending Coins: " + str(pending_coins))
	print("Pending EXP: ")
	print(exp_rewards)

func login(secret: String) -> bool:
	headers = [
		"Authorization: Bearer " + secret,
		"Content-Type: application/json",
		"Notion-Version: 2022-06-28"
	]
	var data = {
		"query": "action rewards project objectives wallet calculator",
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
		header_secret = ""
		is_logged_in = false
		cant_log_in.emit()
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
			for opt in db["properties"]["Source Of Exp."]["select"]["options"]:
				if opt["name"] == "Project":
					project_src_opt["name"] = opt["name"]
					project_src_opt["id"] = opt["id"]
					project_src_opt["color"] = opt["color"]
					project_src_opt["description"] = opt["description"]
				if opt["name"] == "Objective":
					objective_src_opt["name"] = opt["name"]
					objective_src_opt["id"] = opt["id"]
					objective_src_opt["color"] = opt["color"]
					objective_src_opt["description"] = opt["description"]
		elif db["title"][0]["plain_text"] == PROJECT_DB_TITLE:
			projects_database_id = db["id"]
		elif db["title"][0]["plain_text"] == OBJECTIVE_DB_TITLE:
			objectives_database_id = db["id"]
		elif db["title"][0]["plain_text"] == WALLET_DB_TITLE:
			wallet_database_id = db["id"]
		elif db["title"][0]["plain_text"] == EXP_CALCULATOR_DB_TITLE:
			exp_calculator_database_id = db["id"]
		elif db["title"][0]["plain_text"] == CALCULATOR_DB_TITLE:
			calculator_database_id = db["id"]
	
	if actions_database_id.is_empty() or \
			reward_database_id.is_empty() or \
			exp_reward_database_id.is_empty() or \
			projects_database_id.is_empty() or \
			objectives_database_id.is_empty() or \
			wallet_database_id.is_empty() or \
			exp_calculator_database_id.is_empty() or \
			calculator_database_id.is_empty():
		print("Something is wrong with Notion template")
		headers = []
		header_secret = ""
		is_logged_in = false
		cant_log_in.emit()
		return false
	wallet_id = await get_wallet_id()
	exp_calculator_id = await get_exp_calculator_id()
	await update_this_week_period()
	
	http.queue_free()
	is_logged_in = true
	header_secret = secret
	logged_in.emit()
	save_state()
	return true

func logout() -> void:
	headers = []
	header_secret = ""
	save_state()

func update_this_week_period() -> void:
	var url := API_URL + DB_ENDPOINT + "/" + calculator_database_id + "/query"
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url, headers, HTTPClient.METHOD_POST)
	var params := await http.request_completed as Array
	
	var json := JSON.parse_string(params[3].get_string_from_utf8()) as Dictionary
	var results := json["results"] as Array
	if results.size() > 0:
		start_date = results[0]["properties"]["StartOfWeek"]["formula"]["date"]["start"]
		end_date = results[0]["properties"]["EndOfWeek"]["formula"]["date"]["start"]

func get_exp_calculator_id() -> String:
	var url := API_URL + DB_ENDPOINT + "/" + exp_calculator_database_id + "/query"
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url, headers, HTTPClient.METHOD_POST)
	var params := await http.request_completed as Array
	
	var json := JSON.parse_string(params[3].get_string_from_utf8()) as Dictionary
	var results := json["results"] as Array
	if results.size() > 0:
		return results[0]["id"]
	else:
		return ""

func get_wallet_id() -> String:
	var url := API_URL + DB_ENDPOINT + "/" + wallet_database_id + "/query"
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url, headers, HTTPClient.METHOD_POST)
	var params := await http.request_completed as Array
	
	var json := JSON.parse_string(params[3].get_string_from_utf8()) as Dictionary
	var results := json["results"] as Array
	if results.size() > 0:
		return results[0]["id"]
	else:
		return ""

func update_actions_to_collect() -> void:
	actions_to_collect.clear()
	var data := {
		"filter": {
			"or": [
				{
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
				},
				{
				"and": [
					{
						"property" : "Collected",
						"checkbox" : {
							"equals" : false
						}
					},
					{
						"property" : "# Done",
						"formula": {
							"number": { "greater_than": 0 }
						}
					},
					{
						"property" : "Action Type",
						"select": { "equals": ACTION_TYPE_HABIT }
					}
				]
				}
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
	
	var results := json.get("results", []) as Array
	if results.size() == 0:
		print("No actions to collect")
		updated_actions_to_collect.emit()
		http.queue_free()
		return
	
	var start_date_dict := Time.get_datetime_dict_from_datetime_string(start_date, false)
	var start_date_fmt = str(start_date_dict["year"]) + "/" + str(start_date_dict["month"]) + "/" + str(start_date_dict["day"])
	var end_date_dict := Time.get_datetime_dict_from_datetime_string(end_date, false)
	var end_date_fmt = str(end_date_dict["year"]) + "/" + str(end_date_dict["month"]) + "/" + str(end_date_dict["day"])
	print("Period: " + start_date_fmt + "-> " + end_date_fmt)
	
	var total_coins = 0
	var total_bonus = 0
	
	for r in results:
		var action := {
			"id": r["id"],
			"coins": r["properties"]["Total Value (coins)"]["formula"]["number"],
			"type": r["properties"]["Action Type"]["select"]["name"],
			"name": r["properties"]["Name"]["title"][0]["text"]["content"],
			"habit_completed_weeks": r["properties"]["Habit Completed Weeks"]["number"]
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

func update_xp_to_collect() -> void:
	await update_projects_to_collect()
	await update_objectives_to_collect()
	updated_xp_to_collect.emit()

func update_projects_to_collect() -> void:
	projects_to_collect.clear()
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
	
	var json_string = JSON.stringify(data)
	var http := HTTPRequest.new()
	add_child(http)
	var url = API_URL + DB_ENDPOINT + "/"  + projects_database_id + "/query"
	http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	var params = await http.request_completed
	var json = JSON.parse_string(params[3].get_string_from_utf8())
	
	var results := json.get("results", []) as Array
	if results.size() == 0:
		print("No projects to collect")
		updated_projects_to_collect.emit()
		http.queue_free()
		return
	
	for r in results:
		var project := {
			"id": r["id"],
			"exp": r["properties"]["Exp."]["formula"]["number"],
			"aof": r["properties"]["Area of Focus"]["formula"]["string"],
			"name": r["properties"]["Name"]["title"][0]["text"]["content"],
			"src_xp_name": project_src_opt["name"],
			"src_xp_id": project_src_opt["id"],
			"is_pending": false
		}
		var aof_rel := r["properties"]["Area of Focus (Relation)"]["relation"] as Array
		if aof_rel.size() > 0:
			project["aof_id"] = aof_rel[0]["id"]
		else:
			project["aof_id"] = null
		projects_to_collect.append(project)
	
	updated_projects_to_collect.emit()
	http.queue_free()

func update_objectives_to_collect() -> void:
	objectives_to_collect.clear()
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
	
	var json_string = JSON.stringify(data)
	var http := HTTPRequest.new()
	add_child(http)
	var url = API_URL + DB_ENDPOINT + "/"  + objectives_database_id + "/query"
	http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	var params = await http.request_completed
	var json = JSON.parse_string(params[3].get_string_from_utf8())
	
	var results := json.get("results", []) as Array
	if results.size() == 0:
		print("No Objectives to collect")
		updated_objectives_to_collect.emit()
		http.queue_free()
		return
	
	for r in results:
		var objective := {
			"id": r["id"],
			"exp": r["properties"]["CalculatedExp"]["formula"]["number"],
			"aof": r["properties"]["Area of Focus"]["formula"]["string"],
			"name": r["properties"]["Name"]["title"][0]["text"]["content"],
			"src_xp_name": objective_src_opt["name"],
			"src_xp_id": objective_src_opt["id"],
			"is_pending": false
		}
		var aof_rel := r["properties"]["Area of Focus (Relation)"]["relation"] as Array
		if aof_rel.size() > 0:
			objective["aof_id"] = aof_rel[0]["id"]
		else:
			objective["aof_id"] = null
		objectives_to_collect.append(objective)
	
	updated_projects_to_collect.emit()
	http.queue_free()

func collect_all_actions() -> void:
	for action in actions_to_collect:
		if action["type"] == ACTION_TYPE_HABIT and !collect_habits:
			continue
		await collect_action(action)
	all_actions_collected.emit()
	if pending_coins > 0:
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
	if action["type"] == ACTION_TYPE_HABIT and action["habit_bonus"] > 0:
		data["properties"]["Habit Completed Weeks"] = { "number": action["habit_completed_weeks"] + 1 }
	
	print("Collecting action: " + action["name"] + " ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])
	var response_code = params[1]
	if params[1] == 200:
		pending_coins += action["coins"] + action["habit_bonus"]
	else:
		printerr("Error collecting action: " + action["name"])
	http.queue_free()

func collect_all_xp() -> void:
	for project in projects_to_collect:
		await collect_project(project)
	for objective in objectives_to_collect:
		await collect_objective(objective)
	all_xp_collected.emit()
	if has_pending_exp():
		await create_exp_reward()

func collect_project(project: Dictionary) -> void:
	var url = API_URL + PAGES_ENDPOINT + "/" + project["id"]
	var http := HTTPRequest.new()
	add_child(http)
	var data = {
		"properties": {
			"Collected": { "checkbox": true }
		}
	}
	print("Collecting project: " + project["name"] + " ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])
	var response_code = params[1]
	if response_code == 200:
		project["is_pending"] = true
	else:
		printerr("Error collecting project: " + project["name"])
	http.queue_free()

func collect_objective(objective: Dictionary) -> void:
	var url = API_URL + PAGES_ENDPOINT + "/" + objective["id"]
	var http := HTTPRequest.new()
	add_child(http)
	var data = {
		"properties": {
			"Collected": { "checkbox": true }
		}
	}
	print("Collecting objective: " + objective["name"] + " ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])
	var response_code = params[1]
	if response_code == 200:
		objective["is_pending"] = true
	else:
		printerr("Error collecting objective: " + objective["name"])
	http.queue_free()

func create_exp_reward():
	var this_week_exp_rewards := await get_this_week_exp_rewards()
	var exp_to_collect: Array
	exp_to_collect.append_array(projects_to_collect)
	exp_to_collect.append_array(objectives_to_collect)
	for x in exp_to_collect:
		if not x["is_pending"]:
			continue
		var found := false
		for item in exp_rewards:
			if item["aof_id"] == x["aof_id"] and item["src_xp_name"] == x["src_xp_name"]:
				item["exp"] += x["exp"]
				found = true
				continue
		if not found:
			var new_item = {
				"aof_id": x["aof_id"],
				"exp": x["exp"],
				"src_xp_name": x["src_xp_name"],
				"src_xp_id": x["src_xp_id"],
				"is_pending": true
			}
			exp_rewards.append(new_item)
	
	for x in exp_rewards:
		var found := false
		for r in this_week_exp_rewards:
			if x["aof_id"] == r["aof_id"] and x["src_xp_name"] == r["src_xp_name"]:
				found = true
				await update_exp_reward(x, r)
				continue
		if not found and x["aof_id"] != null:
			await create_new_exp_reward(x)
	remove_exp_rewards_not_pending()
	save_state()

func remove_exp_rewards_not_pending() -> void:
	exp_rewards = exp_rewards.filter(func(reward): return reward["is_pending"])

func get_this_week_exp_rewards() -> Array[Dictionary]:
	var url := API_URL + DB_ENDPOINT + "/" + exp_reward_database_id + "/query"
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
	var rewards: Array[Dictionary] = []
	if results.size() > 0:
		for r in results:
			var reward = { 
				"aof_id": r["properties"]["Area Of Focus"]["relation"][0]["id"],
				"exp": r["properties"]["Exp."]["number"],
				"src_xp_id": r["properties"]["Source Of Exp."]["select"]["id"],
				"src_xp_name": r["properties"]["Source Of Exp."]["select"]["name"],
				"id": r["id"]
			}
			rewards.append(reward)
	return rewards

func update_exp_reward(reward: Dictionary, this_week_reward: Dictionary) -> void:
	var url = API_URL + PAGES_ENDPOINT + "/" + this_week_reward["id"]
	var http := HTTPRequest.new()
	add_child(http)
	var data = {
		"properties": {
			"Exp.": this_week_reward["exp"] + reward["exp"]
		}
	}
	print("Updating exp reward ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])
	var response_code = params[1]
	if response_code == 200:
		reward["is_pending"] = false
	else:
		printerr("Error updating exp reward: " + reward["id"])

func create_new_exp_reward(reward: Dictionary) -> void:
	var url = API_URL + PAGES_ENDPOINT
	var http := HTTPRequest.new()
	add_child(http)
	var exp_src: Dictionary
	var data = {
		"parent": { "database_id": exp_reward_database_id },
		"properties": {
			"Area Of Focus": {
				"relation": [
					{ "id": reward["aof_id"] }
				]
			},
			"Period": {
				"date": {
					"start" : start_date,
					"end": end_date,
				}
			},
			"Source Of Exp.": {
				"select": { "id": reward["src_xp_id"]}
			},
			"Exp.": {
				"number": reward["exp"]
			},
			"Exp Calculator": {
				"relation": [
					{ "id": exp_calculator_id }
				]
			}
		}
	}
	
	print("Creating new exp reward ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])
	var response_code = params[1]
	if response_code == 200:
		reward["is_pending"] = false
	else:
		printerr("Error creating exp reward: " + start_date + " -> " + end_date)

func create_reward():
	var this_week_reward := await get_this_week_reward()
	
	if not this_week_reward.is_empty():
		await update_reward(this_week_reward)
	else:
		await create_new_reward()
	reward_updated.emit()
	save_state()

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
		var coins = results[0]["properties"]["Coins"]["number"]
		if coins == null: coins = 0
		return {"id": results[0]["id"], "coins": coins}
	else:
		return {}

func update_reward(reward: Dictionary):
	var url = API_URL + PAGES_ENDPOINT + "/" + reward["id"]
	var http := HTTPRequest.new()
	add_child(http)
	var data = {
		"properties": {
			"Coins": { "number": pending_coins + reward["coins"] }
		}
	}
	print("Updating reward ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])
	var response_code = params[1]
	if response_code == 200:
		pending_coins = 0
	else:
		printerr("Error updating reward: " + reward["id"])

func create_new_reward():
	var url = API_URL + PAGES_ENDPOINT
	var http := HTTPRequest.new()
	add_child(http)
	
	var data = {
		"parent": { "database_id": reward_database_id },
		"properties": {
			"Coins": {
				"number": pending_coins
			},
			"Period": {
				"date": {
					"start" : start_date,
					"end": end_date,
				}
			},
			"Wallet": {
				"relation": [
					{ "id": wallet_id }
				]
			}
		}
	}
	
	print("Creating new reward ... ")
	var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	var params = await http.request_completed
	print(params[1])
	var response_code = params[1]
	if response_code == 200:
		pending_coins = 0
	else:
		printerr("Error creating reward: " + start_date + " -> " + end_date)

func get_total_coins() -> int:
	var total_coins := 0
	for action in actions_to_collect:
		if action["type"] == ACTION_TYPE_HABIT and !collect_habits:
			continue
		total_coins += action["coins"]
	return total_coins

func get_total_bonus() -> int:
	if !collect_habits:
		return 0
	var total_bonus := 0
	for action in actions_to_collect:
		total_bonus += action["habit_bonus"]
	return total_bonus

func get_total_projects_xp() -> int:
	var total_xp := 0
	for p in projects_to_collect:
		total_xp += p["exp"]
	return total_xp

func get_total_objectives_xp() -> int:
	var total_xp := 0
	for o in objectives_to_collect:
		total_xp += o["exp"]
	return total_xp

func has_pending_exp() -> bool:
	var exp_items = []
	exp_items.append_array(projects_to_collect)
	exp_items.append_array(objectives_to_collect)
	
	for i in exp_items:
		if i["is_pending"]:
			return true
	return false

func save_state() -> void:
	var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	var data = {
		"pending_coins": pending_coins,
		"exp_rewards": exp_rewards,
		"header_secret": header_secret
	}
	var json_string = JSON.stringify(data)
	save_file.store_line(json_string)

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return
	var save_file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	var json_string = save_file.get_line()
	var json := JSON.new()
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
		printerr("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return
	var data = json.get_data() as Dictionary
	pending_coins = data.get("pending_coins", 0)
	if data.has("exp_rewards"):
		for i in data["exp_rewards"]:
			exp_rewards.append(i)
	header_secret = data.get("header_secret", "")
