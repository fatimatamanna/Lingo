import { useEffect, useState } from 'react'

function App() {
  // 'checking' -> 'connected' | 'offline'
  const [status, setStatus] = useState('checking')

  useEffect(() => {
    fetch('/api/health')
      .then((res) => (res.ok ? res.json() : Promise.reject(res.status)))
      .then((data) => setStatus(data.ok ? 'connected' : 'offline'))
      .catch(() => setStatus('offline'))
  }, [])

  const message = {
    checking: 'checking backend...',
    connected: 'backend connected',
    offline: 'backend not running',
  }[status]

  const color = {
    checking: 'text-gray-500',
    connected: 'text-green-600',
    offline: 'text-red-600',
  }[status]

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4">
      <h1 className="text-5xl font-bold">Lingo</h1>
      <p className={`text-lg ${color}`}>{message}</p>
    </main>
  )
}

export default App
