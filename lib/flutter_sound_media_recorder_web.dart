/*
 * Copyright 2018, 2019, 2020 Dooboolab.
 *
 * This file is part of Flutter-Sound.
 *
 * Flutter-Sound is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3 (LGPL-V3), as published by
 * the Free Software Foundation.
 *
 * Flutter-Sound is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Flutter-Sound.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'package:flutter_sound_platform_interface/flutter_sound_platform_interface.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
//import 'dart:typed_data';
import 'package:logger/logger.dart' show Level;
import 'package:web/web.dart' as web;
//import 'dart:html';
//import 'package:js/js.dart' as js;
import 'dart:html' as html;
//import 'dart:web_audio';
//import 'flutter_sound_recorder_web.dart';
//import 'dart:js';
import 'flutter_sound_web.dart' show mime_types;
import 'dart:js_interop';
//import 'flutter_sound_web.dart';

class FlutterSoundMediaRecorderWeb {
  //StreamSubscription<Event>? sub;
  web.MediaRecorder? mediaRecorder;
  StreamSink<Uint8List>? streamSink;
  FlutterSoundRecorderCallback? callback;
  var recordedChunks = [];

  @override
  void requestData(
    FlutterSoundRecorderCallback callback,
  ) {
    mediaRecorder!.requestData();
  }

  void error(web.Event event) {
    callback!.log(Level.debug, 'error');
  }

  void stop(web.Event event) {
    callback!.log(Level.debug, 'stop');
    callback!.stopRecorderCompleted(0, true, '');
    recordedChunks = [];
    //streamSink = null;
    mediaRecorder = null;
  }

  void start(web.Event event) {
    callback!.log(Level.debug, 'start');
  }

  void pause(web.Event event) {
    callback!.log(Level.debug, 'pause');
  }

  void resume(web.Event event) {
    callback!.log(Level.debug, 'resume');
  }

  void dataAvailable(web.Event event) async {
    if (event is web.BlobEvent) {
      callback!.log!(Level.debug, 'BlobEvent');
      var jsArrayBuffer = await event.data.arrayBuffer().toDart;
      var byteBuffer = jsArrayBuffer.toDart.asUint8List(0);
      streamSink!.add(byteBuffer);
    } else {
      callback!.log!(Level.debug, 'Unexpected event');
    }
  }

  Future<void> startRecorderToStreamCodec(
    FlutterSoundRecorderCallback cb, {
    required Codec codec,
    StreamSink<Uint8List>? toStream,
    AudioSource? audioSource,
    Duration timeSlice = Duration.zero,
    int numChannels = 1,
    int bitRate = 16000,
    int bufferSize = 8192,
  }) async {
    callback = cb;
    callback!.log(Level.debug, 'Start Recorder to Stream-Codec');
    var t = true.toJS;
    web.MediaStreamConstraints contraints =
        web.MediaStreamConstraints(audio: t);
    final web.MediaStream stream = await web.window.navigator.mediaDevices!
        .getUserMedia(contraints)
        .toDart; // The mic
    web.MediaRecorderOptions options = web.MediaRecorderOptions(
      mimeType: mime_types[codec.index],
      audioBitsPerSecond: bitRate,
    );
    mediaRecorder = new web.MediaRecorder(stream, options);
    streamSink = toStream;
    int toto = mediaRecorder!.audioBitsPerSecond!;
    String titi = mediaRecorder!.mimeType!;

    mediaRecorder!.ondataavailable = dataAvailable.toJS;
    mediaRecorder!.onstart = start.toJS;
    mediaRecorder!.onpause = pause.toJS;
    mediaRecorder!.onresume = resume.toJS;
    mediaRecorder!.onerror = error.toJS;
    mediaRecorder!.onstop = stop.toJS;

    //if (timeSlice == Duration.zero)
    //timeSlice = null;
    if (timeSlice != Duration.zero) {
      mediaRecorder!.start(timeSlice.inMilliseconds);
    } else {
      mediaRecorder!.start();
    }
    callback!.startRecorderCompleted(RecorderState.isRecording.index, true);
  }

  @override
  Future<void> stopRecorder(
    FlutterSoundRecorderCallback callback,
  ) async {
    mediaRecorder!.requestData();
    mediaRecorder!.stop();
  }

  @override
  Future<void> pauseRecorder(
    FlutterSoundRecorderCallback callback,
  ) async {
    mediaRecorder!.pause();
  }

  @override
  Future<void> resumeRecorder(
    FlutterSoundRecorderCallback callback,
  ) async {
    mediaRecorder!.resume();
  }
}
