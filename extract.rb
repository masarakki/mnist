#!/usr/bin/env ruby
# coding: utf-8

require 'bindata'
require 'imageruby'
require 'imageruby-bmp'
require 'fileutils'

require 'benchmark'
require 'pry'
require 'pry-doc'

class Label < BinData::Record
  endian :big
  uint32 :magic_number
  uint32 :images
  array  :answers, type: :uint8, initial_length: :images, lazy: true
end

class Image < BinData::Record
  endian :big
  uint32 :magic_number
  uint32 :images
  uint32 :rows
  uint32 :columns
  array  :pixels, initial_length: :images do
    array initial_length: :columns do
      array initial_length: :rows do
        uint8
      end
    end
  end
end

class LazyImage < BinData::Record
  endian :big
  uint32 :magic_number
  uint32 :images
  uint32 :rows
  uint32 :columns
  array  :pixels, initial_length: :images, lazy: true do
    array initial_length: :columns do
      array initial_length: :rows do
        uint8
      end
    end
  end
end

def save_images(images, dir)
  FileUtils.mkdir(dir) unless File.exist?(dir)
  labels = Label.read(File.open('train-labels-idx1-ubyte'))
  images.pixels.lazy.zip(labels.answers).each_with_index do |data, num|
    pixel, answer = data
    FileUtils.mkdir("#{dir}/#{answer}") unless File.exist?("#{dir}/#{answer}")

    image = ImageRuby::Image.new(images.rows, images.columns)
    pixel.each_with_index do |lines, y|
      lines.each_with_index do |color, x|
        image[x, y] = ImageRuby::Color.from_rgb(color, color, color)
      end
    end
    image.save("#{dir}/#{answer}/#{num}.bmp", :bmp)
  end
end

Benchmark.bm do |r|
  filename = 'train-images-idx3-ubyte'

  r.report "lazy - read" do
    LazyImage.read(File.open(filename))
  end

  r.report "lazy - extract" do
    images = LazyImage.read(File.open(filename))
    save_images(images, 'lazy')
  end

  r.report "not lazy - read" do
    Image.read(File.open(filename))
  end

  r.report "not lazy - extract" do
    images = Image.read(File.open(filename))
    save_images(images, 'not_lazy')
  end
end
