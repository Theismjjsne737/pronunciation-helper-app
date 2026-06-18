import { useState, useRef, useCallback } from 'react';

export function useAudioRecorder() {
  const [isRecording, setIsRecording] = useState(false);
  const [audioURL, setAudioURL] = useState(null);
  const [error, setError] = useState(null);
  const mediaRecorderRef = useRef(null);
  const chunksRef = useRef([]);
  const blobRef = useRef(null);

  const start = useCallback(async () => {
    setError(null);
    setAudioURL(null);
    blobRef.current = null;
    chunksRef.current = [];

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm';

      const mr = new MediaRecorder(stream, { mimeType });
      mediaRecorderRef.current = mr;

      mr.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };

      mr.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: mimeType });
        blobRef.current = blob;
        setAudioURL(URL.createObjectURL(blob));
        // Stop all tracks to release mic
        stream.getTracks().forEach((t) => t.stop());
      };

      mr.start(100); // collect data every 100ms
      setIsRecording(true);
    } catch (err) {
      setError(err.name === 'NotAllowedError'
        ? 'Microphone access denied. Please allow microphone access and try again.'
        : `Could not start recording: ${err.message}`
      );
    }
  }, []);

  const stop = useCallback(() => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
    }
  }, [isRecording]);

  const getBlob = useCallback(() => blobRef.current, []);

  const reset = useCallback(() => {
    setAudioURL(null);
    setError(null);
    blobRef.current = null;
    chunksRef.current = [];
  }, []);

  return { isRecording, audioURL, error, start, stop, getBlob, reset };
}
