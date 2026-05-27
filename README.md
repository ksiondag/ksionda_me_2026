### 📋 Project Context: React/Rust Web App with Advanced Animations

**Current Stack:**
*   **Frontend:** React (TypeScript)
*   **Backend:** Rust (Axum + Tokio)
*   **Infrastructure:** Linode VPS, Nginx (Reverse Proxy), Systemd (Service Manager)

**Architecture Decisions:**
1.  **Hybrid Rendering Strategy:**
    *   **React:** Handles UI structure, routing, forms, and high-level state management.
    *   **D3.js:** Handles complex data visualization and high-framerate animations.
    *   **Integration Pattern:** Use `useRef` to hold D3 selections. Use `useEffect` to initialize D3 on mount and update it when React state changes. **Crucial:** Do not put animation frame coordinates in React `useState` to avoid re-rendering; manipulate the DOM directly via D3 or `requestAnimationFrame`.

2.  **Deployment Flow:**
    *   **Nginx:** Routes `/` to React static build (`/var/www/my-frontend/build`) and proxies `/api/*` to Rust backend on `localhost:8080
`.
    *   **Rust Service:** Run via `systemd` (`/etc/systemd/system/rust-api.service`) to ensure auto-start on reboot.
    *   **Security:** Use `certbot` for HTTPS. Never share SSH keys or passwords in chat.

3.  **Alternative Frontend Consideration (If React proves limiting for animations):**
    *   **Svelte:** Recommended as the primary alternative. It compiles to vanilla JS, has no Virtual DOM overhead, and has built-in `<transition>` support. Excellent integration with D3 for data viz.
    *   **SolidJS:** Alternative if preferring React-like JSX syntax but with fine-grained reactivity (no Virtual DOM).
    *   **PixiJS/Three.js:** Recommended if the project is purely visual/effects-heavy with minimal UI components (bypass React entirely for the canvas layer).

4.  **Key Technical Patterns:**
    *   **TMUX:** Use `Ctrl+b [` to enter copy mode for scrolling. Use `set -g mouse on` in `.tmux.conf` for mouse scrolling.
    *   **Rust Backend:** Use `tower-http::cors` for cross-origin requests from the React frontend.
    *   **Data Flow:** Rust API → JSON → React `fetch` → D3 Calculation → DOM Update.

**Next Steps for Future Sessions:**
*   Implementing HTTPS with Let's Encrypt.
*   Adding a database (PostgreSQL + `sqlx`) to the Rust backend.
*   Refining the D3 + React integration for specific animation types (particles vs. charts).
*   Exploring SvelteKit migration if performance bottlenecks arise in React.

# 🎨 Frontend Architecture: React + D3 Integration Guide

## 1. Core Philosophy: "React for Structure, D3 for Rendering"
The biggest mistake when combining React and D3 is trying to force React to manage the animation loop.
*   **React’s Job:** Manage high-level state (e.g., `userLoggedIn`, `selectedDataset`, `isMenuOpen`), handle user input (clicks, form subm
its), and structure the DOM layout (flexbox/grid).
*   **D3’s Job:** Manipulate the DOM/SVG/Canvas directly for high-frequency updates (60fps animations, complex chart re-renders, physics s
imulations).
*   **The Handshake:** React passes *data* or *flags* to D3; D3 updates the *DOM*. React never touches the animated elements directly duri
ng the frame loop.

## 2. The "Golden Pattern" Implementation
This is the standard, performant way to embed D3 in React.

### A. Component Structure
```tsx
import React, { useRef, useEffect, useState } from 'react';
import * as d3 from 'd3';

interface D3ChartProps {
  data: number[]; // Data changes trigger D3 updates
  isAnimating: boolean; // Flag to start/stop animation loops
}

const D3Chart: React.FC<D3ChartProps> = ({ data, isAnimating }) => {
  // 1. Refs are critical. They hold the DOM elements and D3 selections.
  const svgRef = useRef<SVGSVGElement>(null);
  const animationFrameRef = useRef<number>(); // To cancel loops on unmount

  // 2. Initialize D3 (Runs once on mount)
  useEffect(() => {
    const svg = d3.select(svgRef.current);

    // Setup static elements (axes, groups, scales)
    const g = svg.append('g').attr('class', 'chart-content');

    // Store reference on the DOM node for easy access in other effects
    (svgRef.current as any).__chartGroup = g;

    // Initial render
    renderChart(g, data);

    // Cleanup: Cancel animation loop if it was running
    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, []); // Empty dependency = run only on mount

  // 3. Update D3 when Data Changes (React-controlled)
  useEffect(() => {
    const g = (svgRef.current as any).__chartGroup;
    if (g) {
      renderChart(g, data);
    }
  }, [data]); // Re-run when data prop changes

  // 4. Handle Animation State (React-controlled)
  useEffect(() => {
    const g = (svgRef.current as any).__chartGroup;
    if (!g) return;

    if (isAnimating) {
      startAnimationLoop(g);
    } else {
      stopAnimationLoop();
    }
  }, [isAnimating]);

  // --- Helper Functions ---

  const renderChart = (group: d3.Selection<SVGGElement, any, any, any>, newData: number[]) => {
    // D3 Transition for smooth data updates
    group.selectAll('.bar')
      .data(newData)
      .join(
        enter => enter.append('rect').attr('class', 'bar').attr('height', 0),
        update => update,
        exit => exit.remove()
      )
      .transition().duration(500)
      .attr('height', d => d * 2)
      .attr('y', d => 100 - d * 2);
  };

  const startAnimationLoop = (group: d3.Selection<SVGGElement, any, any, any>) => {
    let angle = 0;
    const animate = () => {
      angle += 0.01;
      // Direct DOM manipulation via D3 (bypasses React render cycle)
      group.select('.moving-element')
        .attr('transform', `rotate(${angle * 57.29})`);

      animationFrameRef.current = requestAnimationFrame(animate);
    };
    animate();
  };

  const stopAnimationLoop = () => {
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
    }
  };

  return <svg ref={svgRef} width="500" height="300" style={{ background: '#f0f0f0' }} />;
};

export default D3Chart;
```

## 3. Critical Rules & Anti-Patterns

### ✅ DO:
*   **Use `useRef` for D3 Selections:** Do not store D3 selections in `useState`. State changes trigger React re-renders, which kills perf
ormance in animation loops.
*   **Use `requestAnimationFrame` for Loops:** Never use `setInterval` for 60fps animations in React. It desyncs from the browser’s displa
y refresh rate.
*   **Use D3 Transitions for Data Changes:** When `data` changes, use `.transition().duration(500)` to animate the change smoothly. This i
s smoother than letting React re-render the whole component.
*   **Clean Up:** Always cancel `requestAnimationFrame` in the `useEffect` cleanup function to prevent memory leaks and background process
ing when the component unmounts.

### ❌ DON'T:
*   **Don't put animation coordinates in State:** Never do `const [x, setX] = useState(0)`. Updating state 60 times a second will cause th
e UI to lag significantly because React will try to diff the Virtual DOM every frame.
*   **Don't use `useEffect` for every frame:** Only use `useEffect` for initialization and data-prop changes.
*   **Don't mix React and D3 for the same elements:** If D3 is manipulating an SVG element, React should not also try to render that same
element via JSX. Pick one source of truth. Usually, D3 owns the SVG internals, React owns the wrapper div.

## 4. Performance Optimization Tips

1.  **Memoize D3 Calculations:** If you are calculating scales or paths based on data, do it inside the `useEffect` that depends on the da
ta, not inside the render function.
2.  **Use Canvas for Mass Elements:** If you have >1,000 animated elements (e.g., particles, thousands of data points), D3’s SVG manipulat
ion will slow down. Switch to **D3 + Canvas** or **PixiJS**.
    *   *D3 + Canvas:* Use `d3-canvas` or manually draw on a `<canvas>` ref using `requestAnimationFrame`.
3.  **Debounce Data Updates:** If your Rust backend is sending data rapidly (e.g., every 10ms), debounce the React state update or use a w
eb worker to process the data before passing it to D3, so the UI thread isn’t blocked.

## 5. Integration with Rust Backend

*   **API Structure:** Expect JSON arrays or objects.
    ```json
    {
      "data": [10, 20, 30],
      "metadata": { "timestamp": 1690000000 }
    }
    ```
*   **Fetching Data:**
    ```tsx
    useEffect(() => {
      const fetchData = async () => {
        const res = await fetch('/api/chart-data');
        const json = await res.json();
        setData(json.data); // Triggers D3 update via useEffect
      };
      fetchData();
      const interval = setInterval(fetchData, 2000);
      return () => clearInterval(interval);
    }, []);
    ```
*   **CORS:** Ensure your Rust backend (`axum`) includes the `tower-http::cors` middleware to allow requests from `localhost:3000` (dev) o
r your domain (prod).

## 6. Alternative: Svelte + D3 (If Performance is Critical)

If React’s overhead becomes a bottleneck:
*   **Svelte** compiles away the Virtual DOM.
*   **Svelte Transitions:** Built-in `<transition>` directives are easier and lighter than React + Framer Motion.
*   **D3 Integration:** Identical to React, but you can use Svelte’s `$:` reactive statements to reactively update D3 selections when data
 changes, often with less boilerplate.
