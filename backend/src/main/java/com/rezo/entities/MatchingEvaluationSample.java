package com.rezo.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.UuidGenerator;

import java.util.UUID;

@Entity
@Table(name = "matching_evaluation_samples")
public class MatchingEvaluationSample {
    @Id
    @GeneratedValue
    @UuidGenerator
    private UUID id;

    @Column(nullable = false, unique = true)
    private int sampleNumber;
    @Column(nullable = false, length = 10)
    private String datasetSplit;
    private double domainMatch;
    private double skillsMatch;
    private double goalMatch;
    private double locationMatch;
    private double typeMatch;
    @Column(nullable = false)
    private boolean liked;

    public UUID getId() { return id; }
    public int getSampleNumber() { return sampleNumber; }
    public void setSampleNumber(int sampleNumber) { this.sampleNumber = sampleNumber; }
    public String getDatasetSplit() { return datasetSplit; }
    public void setDatasetSplit(String datasetSplit) { this.datasetSplit = datasetSplit; }
    public double getDomainMatch() { return domainMatch; }
    public void setDomainMatch(double domainMatch) { this.domainMatch = domainMatch; }
    public double getSkillsMatch() { return skillsMatch; }
    public void setSkillsMatch(double skillsMatch) { this.skillsMatch = skillsMatch; }
    public double getGoalMatch() { return goalMatch; }
    public void setGoalMatch(double goalMatch) { this.goalMatch = goalMatch; }
    public double getLocationMatch() { return locationMatch; }
    public void setLocationMatch(double locationMatch) { this.locationMatch = locationMatch; }
    public double getTypeMatch() { return typeMatch; }
    public void setTypeMatch(double typeMatch) { this.typeMatch = typeMatch; }
    public boolean isLiked() { return liked; }
    public void setLiked(boolean liked) { this.liked = liked; }
}
