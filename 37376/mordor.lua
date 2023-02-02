local Scheduler = require('app.utils.SchedulerHelper')
local MessageIDConst = require('app.const.MessageIDConst')
local SignalConst = require('app.const.SignalConst')
local EVENT_SHOW_SCENE = '_SHOW_SCENE'

-- remote hotload code for debug/hotfix/experiment
local _mordor = {

}
cc.exports.mordor = _mordor

function _mordor:init()
  -- self._signalSdkLogin = G_SignalManager:add(SignalConst.EVENT_SDK_LOGIN, handler(self, self._onSdkLogin))
  -- self._signalSdkLogout = G_SignalManager:add(SignalConst.EVENT_SDK_LOGOUT, handler(self, self._onSdkLogout))
  self._signalLogin = G_SignalManager:add(SignalConst.EVENT_FINISH_LOGIN, handler(self, self._onLogin))
  
  self:_fixAutoLogin()
  self:_onRedPacketRain()
end

function _mordor:_fixAutoLogin()
  if not dailyRobot then return end

  function dailyRobot:accEnterGame()
    local account = self._accAutoList[self._accAutoIndex]
    if account == nil then return end
  
    local serverList = G_ServerListManager:getList()
    local server = nil
    for key, value in pairs(G_ServerListManager:getList() or {}) do
      local serverName = string.match(value:getName(), '[a-zA-Z%d]+')
      if string.upper(serverName) == string.upper(account.server) then
        server = value
        break
      end
    end
  
    if server ~= nil then
      G_GameAgent:setLoginServer(server)
      G_GameAgent:enterGame()
    end
  end
end

function _mordor:_onRedPacketRain()
  G_SignalManager:add('_SHOW_SCENE', function(type, data)
    if data == 'redPacketRain' then
      -- nothing
    end
  end)

  G_NetworkManager:add(32583, function(type, data)
    local index = 1
    for key, value in pairs(data.redpacketInfo or {}) do
      Scheduler.newScheduleOnce(function()
        G_NetworkManager:send(32584, {red_bag_id=value.id})
      end, 0.1*index)
      index = index + 1
    end
  end)
end

function _mordor:_onLogin()
  -- 全局战斗跳过，除迷窟外，登录后再启动FightUI的hack，过早避免报错
  local FightUI = require('app.scene.view.fight.FightUI')
  if FightUI.m__onEnter == nil then
    local fightonEnter = FightUI.onEnter
    FightUI.m__onEnter = fightonEnter
    function FightUI:onEnter()
      fightonEnter(self)
      if not mazeRobot._skip_battle then return end
      Scheduler.newScheduleOnce(function()
        local sceneStack = G_SceneManager._sceneStack
        if sceneStack[#sceneStack]:getName() == 'fight' and string.find(sceneStack[#sceneStack-1]:getName(), 'maze') == nil then
          G_SceneManager:getTopScene():getSceneView()._fightUI:_onJumpTouch()
          G_SceneManager:fightScenePop()
        end
      end, 1.0)
    end
  end

  -- fix getSeasonInfo
  function mineCraftRobot:getSeasonInfo()
    local state, matchTime, startTime, endTime = require('app.scene.view.crossminecraft.CrossMineCraftHelper').getSeasonInfo()
    return json.encode({matchTime=matchTime, startTime=startTime, endTime=endTime})
  end
end

-- 跨服军团 TODO
function _mordor:guildFight(cid, ctype)
  if ctype == nil then ctype = 0 end --打城0，打人1
  if cid == nil then cid = 24 end -- 22石城，23朔方，24乌巢，21街亭

  G_NetworkManager:addOnce(MessageIDConst.ID_S2C_BrawlGuildsFight, function(type, data)

  end)
  G_NetworkManager:send(MessageIDConst.ID_C2S_BrawlGuildsFight, {target_type=ctype, target_id=cid})
end

function _mordor:createButton(texture, title)
  local btn = ccui.Button:create()
  btn:loadTextures(Path.getUICommon(texture), Path.getUICommon(texture))
  btn:addClickEventListener(function ()
    print('click button')
  end)
  btn:ignoreContentAdaptWithSize(false)
  btn:setAnchorPoint(cc.p(0, 0))
  btn:setPosition(0, 0)

  local label = cc.Label:createWithTTF(title, Path.getCommonFont(), 24)
	label:setColor(Colors.BRIGHT_BG_ONE)
	label:setAnchorPoint(cc.p(0, 0))
  label:setPosition(cc.p(0, 0))
  btn:setContentSize(label:getContentSize())
	btn:addChild(label)

  return btn
end

_mordor:init()