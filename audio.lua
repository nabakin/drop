local audio = {}
local decoder_buffer = 2048
local seconds_per_buffer = 0
local queue_size = 8
local decoder_array = {}
if not love.filesystem.getInfo("music") then love.filesystem.createDirectory("music") end
local song_id = 0
local song_name = nil
local is_paused = false
local current_song = nil

function audio.update()
	-- plays first song
	if current_song == nil then
		love.audio.setVolume(0.5)
		next_song()
	end

	-- when song finished, play next one
	if decoder_array[queue_size-1] == nil then
		next_song()
	elseif not is_paused and not current_song:isPlaying() then
		audio.play()
	end

	local check = current_song:getFreeBufferCount()
	if check > 0 then
		time_count = time_count+check*seconds_per_buffer

		for i=0, queue_size-1 do
			decoder_array[i] = decoder_array[i+check]
		end

		while check ~= 0 do
			local tmp = decoder:decode()
			if tmp ~= nil then
				current_song:queue(tmp)
				decoder_array[queue_size-check] = tmp
				check = check-1
			else
				break
			end
		end
	end
end

function audio.loadMusic()
	music_list = recursive_enumerate("music")

	local music_exists = true
	if next(music_list) == nil then
		music_exists = false
	end
	
	return music_exists
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
	return decoder:getDuration()
end

function audio.getQueueSize()
	return queue_size
end

function audio.getDecoderBuffer()
	return decoder_buffer
end

function audio.decoderSeek(t)
	time_count = t
	decoder:seek(t)
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

function audio.get_decoder_sample(buffer)
	local sample_range = decoder_buffer/(bit_depth/8)

	if buffer < 0 or buffer >= sample_range*queue_size then
		love.errhand("buffer out of bounds "..buffer)
	end

	local sample = buffer/sample_range
	local index = math.floor(sample)

	if audio.decoder_tell('samples')+buffer < decoder:getDuration()*sample_rate then
		return decoder_array[index]:getSample((sample-index)*sample_range)
	else
		return 0
	end
end

function audio.decoder_tell(unit)
	if unit == 'samples' then
		return time_count*sample_rate
	else
		return time_count
	end
end

-- File Handling --
function recursive_enumerate(folder)
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
			local recursive_table = recursive_enumerate(file)
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
function next_song()
	song_id = song_id+1
	-- loops songs
	if song_id > #music_list then
		song_id = 1
	end
	
	song_name = music_list[song_id][2]

	decoder = love.sound.newDecoder(music_list[song_id][1], decoder_buffer)
	sample_rate = decoder:getSampleRate()
	bit_depth = decoder:getBitDepth()
	channels = decoder:getChannelCount()
	seconds_per_buffer = decoder_buffer/(sample_rate*channels*bit_depth/8)

	current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
	local check = current_song:getFreeBufferCount()
	time_count = check*seconds_per_buffer
	while check ~= 0 do
		local tmp = decoder:decode()
		if tmp ~= nil then
			current_song:queue(tmp)
			decoder_array[queue_size-check] = tmp
			check = check-1
		end
	end

	audio.play()
end

function prev_song()
	song_id = song_id-1
	-- loops songs
	if song_id < 1 then
		song_id = #music_list
	end
	
	song_name = music_list[song_id][2]

	decoder = love.sound.newDecoder(music_list[song_id][1], decoder_buffer)
	sample_rate = decoder:getSampleRate()
	bit_depth = decoder:getBitDepth()
	channels = decoder:getChannelCount()
	seconds_per_buffer = decoder_buffer/(sample_rate*channels*bit_depth/8)

	current_song = love.audio.newQueueableSource(sample_rate, bit_depth, channels, queue_size)
	local check = current_song:getFreeBufferCount()
	time_count = check*seconds_per_buffer
	while check ~= 0 do
		local tmp = decoder:decode()
		if tmp ~= nil then
			current_song:queue(tmp)
			decoder_array[queue_size-check] = tmp
			check = check-1
		end
	end

	audio.play()
end

return audio