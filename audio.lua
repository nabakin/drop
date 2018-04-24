local audio = {}
local decoder_buffer = 2048
local seconds_per_buffer = 0
local queue_size = 0
local decoder_array = {}
local check_old = 0
local end_of_song = false
if not love.filesystem.getInfo("music") then love.filesystem.createDirectory("music") end
local song_id = 0
local song_name = nil
local is_paused = false
local current_song = nil
local time_count = 0
local music_list = nil

function audio.update()
	-- plays first song
	if current_song == nil then
		love.audio.setVolume(0.5)
		audio.changeSong(1)
	end

	-- when song finished, play next one
	if decoder_array[queue_size] == nil then
		audio.changeSong(1)
  elseif decoder_array[0] == nil then
    audio.changeSong(-1)
    audio.decoderSeek(audio.getDuration())
	elseif not is_paused and not current_song:isPlaying() then
		audio.play()
	end


	-- manage decoder processing and audio queue
	local check = current_song:getFreeBufferCount()
	if check > 0 and not is_paused then
    if end_of_song then
      -- update time_count for the last final miliseconds of the song
      time_count = time_count+(check-check_old)*seconds_per_buffer
      check_old = check
    else
      time_count = time_count+check*seconds_per_buffer
    end

    -- time to make room for new sounddata.  Shift everything.
		for i=0, 2*queue_size-1 do
			decoder_array[i] = decoder_array[i+check]
		end

    -- retrieve new sounddata
		while check > 0 do
			local tmp = decoder:decode()
			if tmp ~= nil then
				current_song:queue(tmp)
				decoder_array[2*queue_size-check] = tmp
				check = check-1
			else
        end_of_song = true
				decoder_array[2*queue_size-check] = tmp
				check = check-1
			end
		end
	end
end

function audio.loadMusic()
	music_list = recursiveEnumerate("music")

	local music_exists = true
	if next(music_list) == nil then
		music_exists = false
	end

	return music_exists
end

function audio.musicExists()
  return music_list ~= nil
end

function audio.isPaused()
	return is_paused
end

function audio.getSongName()
	return song_name
end

function audio.play()
	is_paused = false
	current_song:play()
end

function audio.isPlaying()
	return current_song:isPlaying()
end

function audio.getDuration()
  return decoder ~= nil and decoder:getDuration() or 0
end

function audio.getQueueSize()
	return queue_size
end

function audio.getDecoderBuffer()
	return decoder_buffer
end

-- goes to position in song
function audio.decoderSeek(t)
	time_count = t
  
  -- prevent errors at the beginning of the song
  -- generate nil data (indicates to change song)
  local start = 0
  local offset_time = t-queue_size*seconds_per_buffer
  if t <= 0 then
    local queue_pos = math.ceil((t*-1)/seconds_per_buffer)
    for i=0, queue_pos+1 do
      decoder_array[i] = nil
      start = i+1
    end
    offset_time = t+offset_time
  end
  
  -- fill decoder_array with dummy data
  if offset_time < 0 then
    decoder:seek(0)
    local tmp = decoder:decode()
    local queue_pos = math.ceil((offset_time*-1)/seconds_per_buffer)
    for i=start, queue_pos do
      decoder_array[i] = tmp
      start = i+1
    end
    offset_time = queue_pos+offset_time
  end
  
	decoder:seek(offset_time)
  
  -- fill with new sounddata
  for i=start, queue_size-1 do
    local tmp = decoder:decode()
    if tmp ~= nil then
      decoder_array[i] = tmp
    else
      break
    end
  end
  
  -- clear queued audio
  current_song:stop()
  current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
  
  -- fill with new sounddata
  local check = queue_size
  while check > 0 do
    local tmp = decoder:decode()
    if tmp ~= nil then
      current_song:queue(tmp)
    end
    decoder_array[2*queue_size-check] = tmp
    check = check-1
  end
end

function audio.getBitDepth()
	return bit_depth
end

function audio.pause()
	is_paused = true
	current_song:pause()
end

function audio.getChannels()
	return channels
end

function audio.getSampleRate()
	return sample_rate
end

-- finds sample using decoders
function audio.getDecoderSample(buffer)
	local sample_range = decoder_buffer/(bit_depth/8)

	-- some defensive code..
	if buffer < 0 or buffer >= 2*sample_range*queue_size then
		love.errhand("buffer out of bounds "..buffer)
	end

	local sample = buffer/sample_range
	local index = math.floor(sample)
  
	-- finds sample using decoders
	if audio.decoderTell('samples')+buffer < decoder:getDuration()*sample_rate then
		return decoder_array[index]:getSample((sample-index)*sample_range)
	else
		return 0
	end
end

-- returns position in song
function audio.decoderTell(unit)
	if unit == 'samples' then
		return time_count*sample_rate
	else
		return time_count
	end
end

-- File Handling --
function recursiveEnumerate(folder)
	local format_table = {
		".mp3", ".wav", ".ogg", ".oga", ".ogv",
		".699", ".amf", ".ams", ".dbm", ".dmf",
		".dsm", ".far", ".pat", ".j2b", ".mdl",
		".med", ".mod", ".mt2", ".mtm", ".okt",
		".psm", ".s3m", ".stm", ".ult", ".umx",
		".xm", ".abc", ".mid", ".it"
	}

	local lfs = love.filesystem
	local music_table = lfs.getDirectoryItems(folder)
	local complete_music_table = {}
	local valid_format = false
	local index = 1

	for i,v in ipairs(music_table) do
		local file = folder.."/"..v
		for j,w in ipairs(format_table) do
			if v:sub(-4) == w then
				valid_format = true
				break
			end
		end
		if lfs.getInfo(file)["type"] == "file" and valid_format then
			complete_music_table[index] = {}
			complete_music_table[index][1] = lfs.newFile(file)
			complete_music_table[index][2] = v:sub(1, -5)

			index = index+1
			valid_format = false
		elseif lfs.getInfo(file)["type"] == "directory" then
			local recursive_table = recursiveEnumerate(file)
			for j,w in ipairs(recursive_table) do
				complete_music_table[index] = {}
				complete_music_table[index][1] = w[1]
				complete_music_table[index][2] = w[2]
				
				index = index+1
			end
		end
	end

	return complete_music_table
end

-- Song Handling --
-- only pass 0, 1, and -1 for now
function audio.changeSong(number)
	song_id = song_id+number

	-- loops song table
	if song_id < 1 then
		song_id = #music_list
	elseif song_id > #music_list then
		song_id = 1
	end

	song_name = music_list[song_id][2]

	-- setup decoder info
	decoder = love.sound.newDecoder(music_list[song_id][1], decoder_buffer)
	sample_rate = decoder:getSampleRate()
	bit_depth = decoder:getBitDepth()
	channels = decoder:getChannelCount()
	seconds_per_buffer = decoder_buffer/(sample_rate*channels*bit_depth/8)

	-- start song queue
  end_of_song = false
  check_old = 0
  queue_size = 4+math.max(math.floor(2*spectrum.getSize()/(decoder_buffer/(bit_depth/8))), 1)
	current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
	local check = current_song:getFreeBufferCount()
	time_count = 0
  gui.timestamp_end:setValue(audio.getDuration())
  local tmp = decoder:decode()
  for i=0, queue_size do
    decoder_array[i] = tmp
  end
  check = check-1
	while check ~= 0 do
		tmp = decoder:decode()
		if tmp ~= nil then
			current_song:queue(tmp)
			decoder_array[2*queue_size-check] = tmp
			check = check-1
		end
	end

	if is_paused then audio.pause() else audio.play() end
end

return audio
