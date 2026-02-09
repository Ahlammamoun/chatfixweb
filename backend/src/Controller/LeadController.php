<?php

namespace App\Controller;

use App\Entity\Lead;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;

class LeadController extends AbstractController
{
    #[Route('/api/leads', name: 'api_leads_create', methods: ['POST'])]
    public function create(Request $request, EntityManagerInterface $em): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        if (!$data || !isset($data['email']) || !isset($data['name'])) {
            return $this->json(['error' => 'Champs manquants'], 400);
        }

        $lead = new Lead();
        $lead->setName($data['name']);
        $lead->setEmail($data['email']);
        $lead->setType($data['type'] ?? 'particulier');

        $em->persist($lead);
        $em->flush();

        return $this->json(['message' => 'Inscription à la bêta enregistrée ✅']);
    }
}
