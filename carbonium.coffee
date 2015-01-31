Pictures = new Meteor.Collection 'pictures'
Devices = new Meteor.Collection 'devices'

getDevicesByPictureId = (pictureId) ->
  Devices.find({pictureId: pictureId})

upload_file = (file) ->
  AV.initialize("5m9xcgs9px1w68dfhoixe3px9ol7kjzbhdbo30mvbybzx5ht", "q9bhxqjx4nlm4sq8vcqbucot7l9e19p47s8elywqn34fchtj")
  avFile = new AV.File("dummy_file", file)
  avFile.save().then (saved_file) ->
    Pictures.insert
      url: saved_file.url()
  , (error) ->
    alert("error")

if Meteor.isClient
  Router.configure {}
  Router.map ->
    @route 'welcome',
      waitOn: ->
       Meteor.subscribe('pictures')
      path: '/'
      template: 'pictures'
      data: ->
        intervalId = Session.get 'intervalId'
        Meteor.clearInterval(intervalId) if intervalId
        Session.set 'myDeviceId', undefined
    @route 'picture',
      waitOn: ->
       Meteor.subscribe('picture', @params.picture_id) and
       Meteor.subscribe('devices', @params.picture_id)
      path: '/:picture_id'
      template: 'picture'
      data: ->
        isMouseDown = false
        startX = startY = lastX = lastY = 0
        currentPictureId = @params.picture_id
        parseCssInt = (target, selector) ->
          parseInt(getComputedStyle(target)[selector])
        getMyDevice = ->
          Devices.findOne({_id: Session.get('myDeviceId')})

        Template.picture.helpers
          picture: ->
            currentPicture = Pictures.findOne(currentPictureId)
            unless Session.get 'myDeviceId'
              left = 0
              devices = getDevicesByPictureId(currentPictureId).fetch()
              if devices.length is 0
                top = 0
                left = 0
              else
                top = _.min(devices.map (d) -> d.top)
                left = _.min(devices.map (d) -> d.left)
                left += _.reduce((devices.map (d) -> d.width), ((a,b) -> a + b), 0) #sum
                console.log top,left

              myDeviceId = Devices.insert
                pictureId: currentPictureId
                online: true
                width: jQuery(window).width()
                height: jQuery(window).height()
                top: top
                left: left
                ts: Date.now()
                userAgent: window.navigator.userAgent
              Session.set 'intervalId', Meteor.setInterval ->
                Meteor.call('heartbeat', myDeviceId)
              , 200
              Session.set 'myDeviceId', myDeviceId
            return currentPicture

          getLeft: ->
            getMyDevice().left or 0

          getTop: ->
            getMyDevice().top or 0

          myDevice: getMyDevice

        Template.picture.events
          'dragstart img': (event) ->
            event.preventDefault()
          'mousedown img': (event) ->
            isMouseDown = true
            left = parseCssInt(event.target, 'left')
            top = parseCssInt(event.target, 'top')
            lastX = event.screenX - left
            lastY = event.screenY - top
            #console.log left, top, lastX, lastY
          'mouseup img': (event)->
            isMouseDown = false
            console.log "mouseup"
          'mousemove img': (event) ->
            if isMouseDown
              left = lastX - event.screenX
              top = event.screenY - lastY
              device = getMyDevice()
              Devices.update
                _id: device._id
              ,
                $set:
                  top: top
                  left: left
                  lastestMoved: true
        Devices.find({}).observe
          changed: (newDevice, oldDevice) ->
            if oldDevice and (newDevice.top isnt oldDevice.top or newDevice.left isnt oldDevice.left)
              device = getMyDevice()
              if newDevice._id isnt device._id
                if device.lastestMoved is true
                  Devices.update
                    _id: device._id
                  ,
                    $set:
                      lastestMoved: false
                else
                  leftOffset = newDevice.left - oldDevice.left
                  topOffset = newDevice.top - oldDevice.top
                  console.log leftOffset, topOffset
                  $('#fullsize').css
                    left: parseInt(getComputedStyle(fullsize).left) - leftOffset
                    top: parseInt(getComputedStyle(fullsize).top) + topOffset
          removed: (removedDevice) ->
            device = getMyDevice()
            if removedDevice._id isnt device._id and device.left > removedDevice.left
              $('#fullsize').css
                left: parseInt(getComputedStyle(fullsize).left) + removedDevice.width

      Template.upload.events
        "change .file-input": (event, template) ->
          upload_file(event.target.files[0])

  Template.pictures.helpers
    all: ->
      Pictures.find({})

if Meteor.isServer
  Meteor.methods
    heartbeat: (deviceId) ->
      Devices.update
        _id: deviceId
      ,
        $set:
          ts: Date.now()

  if Pictures.find({}).fetch().length is 0
    Pictures.insert
      url: "http://bbs.c114.net/uploadImages/200412912265686500.jpg"
    Pictures.insert
      url: "http://image.tianjimedia.com/uploadImages/2012/353/4Q530MU50I69_glaciers1.jpg"
    Pictures.insert
      url: "http://pic.putaojiayuan.com/uploadfile/tuku/WuFengQuanGing/12190330244885.jpg"

  Meteor.publish "pictures", ->
    Pictures.find({})

  Meteor.publish "picture", (pictureId) ->
    Pictures.find(pictureId)

  Meteor.publish "devices", (pictureId) ->
    getDevicesByPictureId pictureId

  Meteor.startup ->
    Meteor.setInterval ->
      Devices.remove {ts: {$lt: Date.now() - 1000}}
      console.log Devices.find({}).fetch()
    , 1000

