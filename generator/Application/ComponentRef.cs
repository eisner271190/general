namespace Generator.Application;

// Referencia a un componente del catalogo: tipo (backend/frontend/cloud) y nombre.
internal sealed record ComponentRef(string Type, string Name);
