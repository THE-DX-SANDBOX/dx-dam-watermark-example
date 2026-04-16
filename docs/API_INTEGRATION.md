# 🔗 Connecting Your UI to the Backend

This guide shows you how to connect your application UI to the backend services provided by this template.

## Quick Start

The migration script automatically creates an API client at `packages/portlet-v1/src/lib/api.ts`. Use it like this:

```typescript
import { api } from './lib/api'

// Your component
export function MyComponent() {
  const [data, setData] = useState([])
  
  useEffect(() => {
    // Call your backend API
    api.get('/api/items').then(setData)
  }, [])
  
  return <div>{/* render data */}</div>
}
```

That's it! The API client handles:
- ✅ Base URL configuration
- ✅ JSON serialization
- ✅ Error handling
- ✅ Timeouts
- ✅ Request/response formatting

## API Client Reference

### GET Request

```typescript
import { api } from './lib/api'

// Fetch all items
const items = await api.get<Item[]>('/api/items')

// Fetch single item
const item = await api.get<Item>('/api/items/123')

// With query parameters
const filtered = await api.get<Item[]>('/api/items?category=electronics&limit=10')
```

### POST Request

```typescript
import { api } from './lib/api'

// Create new item
const newItem = await api.post<Item>('/api/items', {
  name: 'New Product',
  price: 29.99,
  category: 'electronics'
})

// With complex data
const result = await api.post('/api/orders', {
  items: [{ id: 1, quantity: 2 }],
  customer: { id: 123 },
  shippingAddress: { /* ... */ }
})
```

### PUT Request

```typescript
import { api } from './lib/api'

// Update existing item
const updated = await api.put<Item>('/api/items/123', {
  name: 'Updated Name',
  price: 34.99
})

// Partial update
await api.put('/api/items/123', {
  price: 24.99
})
```

### DELETE Request

```typescript
import { api } from './lib/api'

// Delete item
await api.delete('/api/items/123')

// Soft delete
await api.post('/api/items/123/archive', {})
```

## Real-World Examples

### Example 1: Product List Component

```typescript
import { useEffect, useState } from 'react'
import { api } from './lib/api'

interface Product {
  id: number
  name: string
  price: number
  image: string
}

export function ProductList() {
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    loadProducts()
  }, [])

  const loadProducts = async () => {
    try {
      setLoading(true)
      const data = await api.get<Product[]>('/api/products')
      setProducts(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load products')
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <div>Loading...</div>
  if (error) return <div>Error: {error}</div>

  return (
    <div className="product-grid">
      {products.map(product => (
        <div key={product.id} className="product-card">
          <img src={product.image} alt={product.name} />
          <h3>{product.name}</h3>
          <p>${product.price}</p>
        </div>
      ))}
    </div>
  )
}
```

### Example 2: Form Submission

```typescript
import { useState } from 'react'
import { api } from './lib/api'

interface FormData {
  name: string
  email: string
  message: string
}

export function ContactForm() {
  const [formData, setFormData] = useState<FormData>({
    name: '',
    email: '',
    message: ''
  })
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    try {
      setSubmitting(true)
      await api.post('/api/contact', formData)
      setSuccess(true)
      setFormData({ name: '', email: '', message: '' })
    } catch (error) {
      alert('Failed to submit form. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      {success && <div className="success">Message sent!</div>}
      
      <input
        type="text"
        value={formData.name}
        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
        placeholder="Name"
        required
      />
      
      <input
        type="email"
        value={formData.email}
        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
        placeholder="Email"
        required
      />
      
      <textarea
        value={formData.message}
        onChange={(e) => setFormData({ ...formData, message: e.target.value })}
        placeholder="Message"
        required
      />
      
      <button type="submit" disabled={submitting}>
        {submitting ? 'Sending...' : 'Send Message'}
      </button>
    </form>
  )
}
```

### Example 3: CRUD Operations

```typescript
import { useState, useEffect } from 'react'
import { api } from './lib/api'

interface Todo {
  id: number
  title: string
  completed: boolean
}

export function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([])
  const [newTitle, setNewTitle] = useState('')

  useEffect(() => {
    loadTodos()
  }, [])

  const loadTodos = async () => {
    const data = await api.get<Todo[]>('/api/todos')
    setTodos(data)
  }

  const addTodo = async () => {
    if (!newTitle.trim()) return
    
    const newTodo = await api.post<Todo>('/api/todos', {
      title: newTitle,
      completed: false
    })
    
    setTodos([...todos, newTodo])
    setNewTitle('')
  }

  const toggleTodo = async (todo: Todo) => {
    const updated = await api.put<Todo>(`/api/todos/${todo.id}`, {
      ...todo,
      completed: !todo.completed
    })
    
    setTodos(todos.map(t => t.id === updated.id ? updated : t))
  }

  const deleteTodo = async (id: number) => {
    await api.delete(`/api/todos/${id}`)
    setTodos(todos.filter(t => t.id !== id))
  }

  return (
    <div>
      <div className="add-todo">
        <input
          value={newTitle}
          onChange={(e) => setNewTitle(e.target.value)}
          placeholder="New todo..."
        />
        <button onClick={addTodo}>Add</button>
      </div>

      <ul>
        {todos.map(todo => (
          <li key={todo.id}>
            <input
              type="checkbox"
              checked={todo.completed}
              onChange={() => toggleTodo(todo)}
            />
            <span style={{ textDecoration: todo.completed ? 'line-through' : 'none' }}>
              {todo.title}
            </span>
            <button onClick={() => deleteTodo(todo.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

### Example 4: React Query Integration

For more advanced data fetching, combine with React Query:

```bash
cd packages/portlet-v1
npm install @tanstack/react-query
```

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from './lib/api'

interface Item {
  id: number
  name: string
}

export function ItemList() {
  const queryClient = useQueryClient()

  // Fetch items
  const { data: items, isLoading } = useQuery({
    queryKey: ['items'],
    queryFn: () => api.get<Item[]>('/api/items')
  })

  // Create item
  const createMutation = useMutation({
    mutationFn: (newItem: Omit<Item, 'id'>) =>
      api.post<Item>('/api/items', newItem),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['items'] })
    }
  })

  // Delete item
  const deleteMutation = useMutation({
    mutationFn: (id: number) => api.delete(`/api/items/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['items'] })
    }
  })

  if (isLoading) return <div>Loading...</div>

  return (
    <div>
      <button onClick={() => createMutation.mutate({ name: 'New Item' })}>
        Add Item
      </button>

      <ul>
        {items?.map(item => (
          <li key={item.id}>
            {item.name}
            <button onClick={() => deleteMutation.mutate(item.id)}>
              Delete
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

## Environment Configuration

### Local Development

If you need to override Vite-specific frontend variables, create `packages/portlet-v1/.env` yourself. This file is optional and is not part of the standard repo setup.

Example:

```env
# Local backend (default)
VITE_API_BASE_URL=http://localhost:3000

# Or use port-forwarded service
VITE_API_BASE_URL=http://localhost:8080

# Timeout (30 seconds)
VITE_API_TIMEOUT=30000
```

### Production Deployment

For the standard repo workflow, keep your deployment configuration in the root `.env` file and only use `packages/portlet-v1/.env` for manual frontend-only overrides.

If you do create a package-local Vite env file, the backend URL can be set like this:

```env
VITE_API_BASE_URL=http://your-service-name.your-namespace.svc.cluster.local:3000
```

## Custom API Client

If you need more control, create a custom client:

```typescript
// src/lib/custom-api.ts
import { APIClient } from './api'

class CustomAPIClient extends APIClient {
  // Add authentication
  async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const token = localStorage.getItem('auth_token')
    
    return super.request<T>(endpoint, {
      ...options,
      headers: {
        ...options.headers,
        Authorization: token ? `Bearer ${token}` : '',
      },
    })
  }

  // Add custom methods
  async uploadFile(file: File): Promise<{ url: string }> {
    const formData = new FormData()
    formData.append('file', file)

    const response = await fetch(`${this.baseURL}/api/upload`, {
      method: 'POST',
      body: formData,
    })

    return response.json()
  }
}

export const customApi = new CustomAPIClient()
```

## Error Handling

### Global Error Boundary

```typescript
import { Component, ErrorInfo, ReactNode } from 'react'

interface Props {
  children: ReactNode
}

interface State {
  hasError: boolean
  error?: Error
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('API Error:', error, errorInfo)
    
    // Log to backend
    api.post('/api/logs/error', {
      error: error.message,
      stack: error.stack,
      componentStack: errorInfo.componentStack,
    }).catch(console.error)
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <h1>Something went wrong</h1>
          <p>{this.state.error?.message}</p>
          <button onClick={() => window.location.reload()}>
            Reload Page
          </button>
        </div>
      )
    }

    return this.props.children
  }
}
```

### Request-Level Error Handling

```typescript
import { api } from './lib/api'

async function fetchData() {
  try {
    const data = await api.get('/api/data')
    return { data, error: null }
  } catch (error) {
    if (error instanceof Error) {
      // Handle specific errors
      if (error.message.includes('timeout')) {
        return { data: null, error: 'Request timed out. Please try again.' }
      }
      if (error.message.includes('404')) {
        return { data: null, error: 'Resource not found.' }
      }
      if (error.message.includes('500')) {
        return { data: null, error: 'Server error. Please try again later.' }
      }
      return { data: null, error: error.message }
    }
    return { data: null, error: 'An unknown error occurred.' }
  }
}
```

## Debugging Tips

### Enable Request Logging

```typescript
// src/lib/api.ts
export class APIClient {
  async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    // Log request
    console.log('API Request:', {
      endpoint,
      method: options.method || 'GET',
      body: options.body,
    })

    const response = await fetch(`${this.baseURL}${endpoint}`, options)
    
    // Log response
    console.log('API Response:', {
      endpoint,
      status: response.status,
      ok: response.ok,
    })

    const data = await response.json()
    
    // Log data
    console.log('API Data:', data)
    
    return data
  }
}
```

### Network Tab

Use browser DevTools Network tab to inspect:
- Request URL
- Request headers
- Request payload
- Response status
- Response headers
- Response body

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| CORS error | Backend not configured | Add CORS headers to backend |
| 404 Not Found | Wrong endpoint | Check API route in backend |
| Timeout | Slow backend | Increase `VITE_API_TIMEOUT` |
| 401 Unauthorized | Missing auth | Add authentication headers |
| Network error | Backend down | Check backend is running |

## Testing API Integration

### Unit Tests

```typescript
// __tests__/api.test.ts
import { api } from '../lib/api'

// Mock fetch
global.fetch = jest.fn()

describe('API Client', () => {
  beforeEach(() => {
    (fetch as jest.Mock).mockClear()
  })

  it('should make GET request', async () => {
    (fetch as jest.Mock).mockResolvedValueOnce({
      ok: true,
      json: async () => ({ id: 1, name: 'Test' }),
    })

    const result = await api.get('/api/items/1')

    expect(fetch).toHaveBeenCalledWith(
      'http://localhost:3000/api/items/1',
      expect.objectContaining({ method: 'GET' })
    )
    expect(result).toEqual({ id: 1, name: 'Test' })
  })
})
```

### Integration Tests

```typescript
// __tests__/integration.test.ts
import { render, screen, waitFor } from '@testing-library/react'
import { ItemList } from '../components/ItemList'

// Use MSW for API mocking
import { rest } from 'msw'
import { setupServer } from 'msw/node'

const server = setupServer(
  rest.get('/api/items', (req, res, ctx) => {
    return res(ctx.json([
      { id: 1, name: 'Item 1' },
      { id: 2, name: 'Item 2' },
    ]))
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

test('loads and displays items', async () => {
  render(<ItemList />)

  await waitFor(() => {
    expect(screen.getByText('Item 1')).toBeInTheDocument()
    expect(screen.getByText('Item 2')).toBeInTheDocument()
  })
})
```

## Summary

After migration, connecting to your backend is simple:

1. **Import the API client**:
   ```typescript
   import { api } from './lib/api'
   ```

2. **Make requests**:
   ```typescript
   const data = await api.get('/api/endpoint')
   ```

3. **Configure environment**:
   ```env
   VITE_API_BASE_URL=http://localhost:3000
   ```

4. **Handle errors**:
   ```typescript
   try { await api.get('/api/data') }
   catch (error) { /* handle */ }
   ```

The API client is production-ready with:
- ✅ Type safety (TypeScript)
- ✅ Error handling
- ✅ Timeouts
- ✅ JSON serialization
- ✅ Environment configuration

**You're ready to build full-stack applications!** 🚀
