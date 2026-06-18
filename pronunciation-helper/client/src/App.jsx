import { useState } from 'react';
import LandingPage from './pages/LandingPage.jsx';
import ChatPage from './pages/ChatPage.jsx';

export default function App() {
  const [targetName, setTargetName] = useState(null);

  if (!targetName) {
    return <LandingPage onStart={setTargetName} />;
  }

  return <ChatPage targetName={targetName} onReset={() => setTargetName(null)} />;
}
