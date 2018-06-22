local ffi = require("ffi")

-- initialize ffi
ffi.cdef[[
float* fft(float *samples, int nSamples, int tickCount);
]]
local fft = ffi.load(ffi.os == "Windows" and "fft" or "./libfft.dylib")

-- fft gen
local spectrum = {}
local size = config.sampling_size
local old_sample = 0
local samples_ptr = nil

-- spectrum draw
local visualizer_type = config.visualization
local tick_amplitude_average = 0
local tick_count = 128
local fade_activated = config.fade
local fade_intensity_multiplier = config.fade_intensity_multiplier

function spectrum.reload()
  -- fft gen
  old_sample = 0
  samples_ptr = nil

  -- spectrum draw
  tick_amplitude_average = 0
end

function spectrum.generateWaveform()
  local wave = {}
  local channels = audio.getChannels()

  --[[ generates wave input for fft from audio. Optimized
  to take any number of channels (ex: Mono, Stereo, 5.1, 7.1)
  Not completely supported by Love2D yet ]]
  local range = 2*audio.getQueueSize()*audio.getDecoderBuffer()/(audio.getBitDepth()/8)
  for i=1, size do
    local new_sample = 0
    for j=0, channels-1 do
      local x = range/2-size*channels/2+(i-1)*channels+j --calculates sample index and centers it
      new_sample = new_sample+audio.music.getSample(x) --obtains samples and sums them
    end
    new_sample = new_sample/channels --averages sample
    table.insert(wave, new_sample)
  end
  old_sample = audio.music.tellSong('samples')

  -- wave->normalized spectrum using ffi
  samples_ptr = ffi.new("float["..size.."]", wave) -- keeps ffi memory allocated, don't destroy
  local sample_count_ptr = ffi.new("int", size)
  local tick_count_ptr = ffi.new("int", tick_count)

  return fft.fft(samples_ptr, sample_count_ptr, tick_count_ptr)
end

function spectrum.generateMicrophoneWaveform()
  local wave = {}
  local channels = audio.getChannels()
  
  --[[ generates wave input for fft from audio. Optimized
  to take any number of channels (ex: Mono, Stereo, 5.1, 7.1)
  Not completely supported by Love2D yet ]]
  for i=1, size do
    local new_sample = 0
    for j=0, channels-1 do
      local x = audio.recordingdevice.getSampleSum()-size*channels+(i-1)*channels+j --calculates sample index and centers it
      new_sample = new_sample+audio.recordingdevice.getSample(x) --obtains samples and sums them
    end
    new_sample = new_sample/channels --averages sample
    table.insert(wave, new_sample)
  end

  -- wave->normalized spectrum using ffi
  samples_ptr = ffi.new("float["..size.."]", wave) -- keeps ffi memory allocated, don't destroy
  local sample_count_ptr = ffi.new("int", size)
  local tick_count_ptr = ffi.new("int", tick_count)

  return fft.fft(samples_ptr, sample_count_ptr, tick_count_ptr)
end

function spectrum.draw(waveform)
  local tick_distance
  local tick_width
  local graphics_width = gui.graphics.getWidth()
  local graphics_height = gui.graphics.getHeight()
  local graphics_scaled_height = math.max(71.138*graphics_height^(1/3), graphics_height) --scales spectrum at a decreasing rate

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
    local tick_padding = 2
    tick_distance = graphics_width/((tick_count+tick_padding)*2)
    tick_width = tick_distance
  elseif visualizer_type == 4 then
    tick_count = 256
    tick_distance = graphics_width/(tick_count*2)
    tick_width = tick_distance
  end

  -- visualization fade
  if fade_activated then
    gui.graphics.setColor(nil, (.03-spectrum.getAverageTickAmplitude())*fade_intensity_multiplier)
  else
    gui.graphics.setColor()
  end
  
  -- draw bar visualization
  local tick_amplitude_sum = 0
  if waveform[0] == nil then tick_count = 0 end
  for i=0, tick_count-1 do
    local tick_amplitude = waveform[i]
    local tick_height = math.max(graphics_scaled_height*tick_amplitude*2, tick_width/2)

    love.graphics.rectangle(
      'fill', graphics_width/2+i*tick_distance,
      graphics_height/2 - tick_height/2,
      tick_width, tick_height,
      tick_width/2, tick_width/2
    )
    love.graphics.rectangle(
      'fill', graphics_width/2-(i+1)*tick_distance,
      graphics_height/2 - tick_height/2,
      tick_width, tick_height,
      tick_width/2, tick_width/2
    )

    tick_amplitude_sum = tick_amplitude_sum + tick_amplitude
  end

  tick_amplitude_average = tick_amplitude_sum/tick_count
end

function spectrum.setVisualization(v)
  visualizer_type = v
end

function spectrum.getVisualization()
  return visualizer_type
end

function spectrum.setFade(f)
  fade_activated = f
  if not f then gui.graphics.setColor(nil, 0) end
end

function spectrum.isFading()
  return fade_activated
end

function spectrum.getAverageTickAmplitude()
  return tick_amplitude_average
end

-- determine if sample position has changed
function spectrum.wouldChange()
  return (audio.music.tellSong('samples') ~= old_sample) or (audio.recordingdevice.isActive() and not audio.isPaused())
end

function spectrum.getSize()
  return size
end

return spectrum
