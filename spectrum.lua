require 'luafft'

-- fft gen
local spectrum = {}
local delay_initial_time = 0
local old_sample = 0

-- spectrum draw
local visualizer_type = 3
local tick_amplitude_average = 0

function spectrum.generateWaveform(delay_seconds)
	local wave = {}
	local size = next_possible_size(1024)
	local sample = audio.getSampleRate()*delay_seconds

	-- to estimate delay for spectrum
	delay_initial_time = love.timer.getTime()

	--[[ generates wave input for fft from audio
	Optimized to take any number of channels (ex: Mono, Stereo, 5.1, 7.1) and grab
	average samples (makes visualization smoother). Not supported by Love2D yet ]]
	local sampling_size = audio.getBitDepth()/4 --number of samples to average
	local range = audio.getQueueSize()*audio.getDecoderBuffer()/(audio.getBitDepth()/8)-1
	local scaled_sampling_size = sampling_size*audio.getChannels()
	for i=sample, sample+size-1 do
		local new_sample = 0
		for j=1, scaled_sampling_size do
			local x = math.min(i*audio.getChannels()+j-1-scaled_sampling_size/2, range)
			new_sample = new_sample+audio.getDecoderSample(math.max(x, 0)) --scales sample size index, centers it, obtains samples, and sums them
		end
		new_sample = new_sample/scaled_sampling_size --averages sample
		table.insert(wave, complex.new(new_sample, 0))
	end
	old_sample = audio.decoderTell('samples')

	-- wave->spectrum takes most CPU usage
	local spectrum = fft(wave, false)

	function divide(list, factor)
		for i,v in ipairs(list) do
			list[i] = list[i] / factor
		end
	end

	-- normalizes spectrum
	divide(spectrum, size/2)
	return spectrum
end

function spectrum.draw(waveform)
	local tick_count
	local tick_distance
	local tick_width
	local graphics_width = gui.graphics:getWidth()
	local graphics_height = gui.graphics:getHeight()

	-- load settings
	if visualizer_type == 1 then
		tick_count = 48
		tick_distance = graphics_width/(tick_count*2)
		tick_width = graphics_width/(tick_count*5.5)
	elseif visualizer_type == 2 then
		tick_count = 64
		tick_distance = graphics_width/(tick_count*2)
		tick_width = graphics_width/(tick_count*4.3)
	elseif visualizer_type == 3 then
		tick_count = 128
		tick_distance = graphics_width/(tick_count*2)
		tick_width = graphics_width/(tick_count*2)
	elseif visualizer_type == 4 then
		tick_count = 48
		tick_distance = graphics_width/(tick_count*2)
		tick_width = graphics_width/(tick_count*2)
	end

	local tick_amplitude_sum = 0

	-- draw bar visualization
	setColor()
	if #waveform == 0 then tick_count = 0 end
	for i=1, tick_count do
		local tick_amplitude = waveform[i]
		local tick_height = graphics_height*tick_amplitude:abs()*2

		love.graphics.rectangle(
			'fill', graphics_width/2+(i-1)*tick_distance,
			graphics_height/2 - tick_height/2,
			tick_width, tick_height,
			tick_width/2, tick_width/2
		)
		love.graphics.rectangle(
			'fill', graphics_width/2-(i-1)*tick_distance,
			graphics_height/2 - tick_height/2,
			tick_width, tick_height,
			tick_width/2, tick_width/2
		)

		tick_amplitude_sum = tick_amplitude_sum + tick_amplitude:abs()
	end

	tick_amplitude_average = tick_amplitude_sum/tick_count
end

-- determine if sample position has changed
function spectrum.wouldChange()
	return (audio.decoderTell('samples') ~= old_sample and not audio.isPaused())
end

function spectrum.setVisualization(v)
	visualizer_type = v
end

function spectrum.getVisualization()
	return visualizer_type
end

function spectrum.getAverageTickAmplitude()
	return tick_amplitude_average
end

function spectrum.getDelayInitialTime()
	return delay_initial_time
end

return spectrum
